//
//  VolumeManager.swift
//  KikoNotchKit
//
//  Real CoreAudio system volume manager based on Boring Notch foundation.
//

import AppKit
import Combine
import CoreAudio
import Foundation

@MainActor
public final class VolumeManager: NSObject, ObservableObject {
    public static let shared = VolumeManager()

    @Published public private(set) var rawVolume: Float = 0.5
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var isSupported: Bool = true
    @Published public private(set) var lastChangeAt: Date = .distantPast

    private let step: Float32 = 1.0 / 16.0
    private var didInitialFetch = false
    private var previousVolumeBeforeMute: Float32 = 0.2
    private var softwareMuted: Bool = false

    public override init() {
        super.init()
        setupAudioListener()
        fetchCurrentVolume()
    }

    // MARK: - Public Control API

    public func increase(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current + delta))
        setAbsolute(target)
    }

    public func decrease(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current - delta))
        setAbsolute(target)
    }

    public func toggleMute() {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown {
            softwareMuted.toggle()
            isMuted = softwareMuted
            if softwareMuted {
                previousVolumeBeforeMute = rawVolume
                rawVolume = 0
            } else {
                rawVolume = previousVolumeBeforeMute
            }
            lastChangeAt = Date()
            return
        }

        toggleMuteInternal()
    }

    public func setAbsolute(_ value: Float32) {
        let clamped = max(0, min(1, value))
        let currentlyMuted = isMutedInternal()
        if currentlyMuted && clamped > 0 {
            toggleMuteInternal()
        }

        writeVolumeInternal(clamped)

        if clamped == 0 && !currentlyMuted {
            toggleMuteInternal()
        }

        publish(volume: clamped, muted: isMutedInternal(), touchDate: true)
    }

    public func refresh() {
        fetchCurrentVolume()
    }

    // MARK: - CoreAudio Internal Queries

    private func systemOutputDeviceID() -> AudioObjectID {
        var defaultDeviceID = kAudioObjectUnknown
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )
        if status != noErr { return kAudioObjectUnknown }
        return defaultDeviceID
    }

    private func fetchCurrentVolume() {
        let deviceID = systemOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else {
            isSupported = false
            return
        }

        var volumes: [Float32] = []
        let candidateElements: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2, 3, 4]
        for element in candidateElements {
            if let v = readValidatedScalar(deviceID: deviceID, element: element) {
                volumes.append(v)
            }
        }

        if !volumes.isEmpty {
            let avg = max(0, min(1, volumes.reduce(0, +) / Float32(volumes.count)))
            isSupported = true
            if rawVolume != avg {
                if didInitialFetch {
                    lastChangeAt = Date()
                }
            }
            rawVolume = avg
            didInitialFetch = true
        } else {
            isSupported = false
        }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            var sizeNeeded: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
               sizeNeeded == UInt32(MemoryLayout<UInt32>.size) {
                var muted: UInt32 = 0
                var mSize = sizeNeeded
                if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mSize, &muted) == noErr {
                    let newMuted = muted != 0
                    if isMuted != newMuted {
                        lastChangeAt = Date()
                    }
                    isMuted = newMuted
                }
            }
        }
    }

    private func setupAudioListener() {
        let deviceID = systemOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, DispatchQueue.main
        ) { [weak self] _, _ in
            self?.fetchCurrentVolume()
        }

        var masterAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &masterAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &masterAddr, DispatchQueue.main) { [weak self] _, _ in
                self?.fetchCurrentVolume()
            }
        } else {
            for ch in [UInt32(1), UInt32(2)] {
                var chAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                if AudioObjectHasProperty(deviceID, &chAddr) {
                    AudioObjectAddPropertyListenerBlock(deviceID, &chAddr, DispatchQueue.main) { [weak self] _, _ in
                        self?.fetchCurrentVolume()
                    }
                }
            }
        }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, DispatchQueue.main) { [weak self] _, _ in
                self?.fetchCurrentVolume()
            }
        }
    }

    private func readVolumeInternal() -> Float32? {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return nil }
        var collected: [Float32] = []
        for el in [kAudioObjectPropertyElementMain, 1, 2, 3, 4] {
            if let v = readValidatedScalar(deviceID: deviceID, element: el) {
                collected.append(v)
            }
        }
        guard !collected.isEmpty else { return nil }
        return collected.reduce(0, +) / Float32(collected.count)
    }

    private func writeVolumeInternal(_ value: Float32) {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return }
        let newVal = max(0, min(1, value))

        if !writeValidatedScalar(deviceID: deviceID, element: kAudioObjectPropertyElementMain, value: newVal) {
            for el in [UInt32](1...4) {
                _ = writeValidatedScalar(deviceID: deviceID, element: el, value: newVal)
            }
        }
    }

    private func readValidatedScalar(deviceID: AudioObjectID, element: UInt32) -> Float32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        var val: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &val)
        guard status == noErr, val.isFinite else { return nil }
        return max(0, min(1, val))
    }

    private func writeValidatedScalar(deviceID: AudioObjectID, element: UInt32, value: Float32) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable: DarwinBoolean = false
        if AudioObjectIsPropertySettable(deviceID, &address, &settable) != noErr || !settable.boolValue {
            return false
        }
        var target = max(0, min(1, value))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &target) == noErr
    }

    private func isMutedInternal() -> Bool {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return softwareMuted }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return softwareMuted }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted) == noErr {
            return muted != 0
        }
        return softwareMuted
    }

    private func toggleMuteInternal() {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown {
            softwareMuted.toggle()
            publish(volume: softwareMuted ? 0 : rawVolume, muted: softwareMuted, touchDate: true)
            return
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else {
            softwareMuted.toggle()
            publish(volume: softwareMuted ? 0 : rawVolume, muted: softwareMuted, touchDate: true)
            return
        }

        var settable: DarwinBoolean = false
        if AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr, settable.boolValue {
            var currentMuted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &currentMuted) == noErr {
                var newMuted: UInt32 = (currentMuted == 0) ? 1 : 0
                if AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newMuted) == noErr {
                    publish(volume: rawVolume, muted: newMuted != 0, touchDate: true)
                    return
                }
            }
        }

        softwareMuted.toggle()
        publish(volume: softwareMuted ? 0 : rawVolume, muted: softwareMuted, touchDate: true)
    }

    private func publish(volume: Float, muted: Bool, touchDate: Bool) {
        if touchDate { self.lastChangeAt = Date() }
        self.rawVolume = volume
        self.isMuted = muted
    }
}
