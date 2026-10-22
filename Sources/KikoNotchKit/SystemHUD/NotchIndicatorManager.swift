//
//  NotchIndicatorManager.swift
//  KikoNotchKit
//
//  Central coordinator for native-style contextual indicators directly beneath the physical notch.
//  Detects system volume and display brightness changes, coordinates with media banners,
//  and manages the single under-notch progress bar lifecycle.
//

import AppKit
import Combine
import CoreAudio
import CoreGraphics
import Foundation
import SwiftUI

public enum NotchIndicatorType: String, Sendable, Equatable {
    case volume
    case brightness
}

public final class NotchIndicatorManager: ObservableObject, @unchecked Sendable {
    public static let shared = NotchIndicatorManager()

    @Published public private(set) var activeIndicator: NotchIndicatorType? = nil
    @Published public private(set) var currentLevel: Float = 0.0
    @Published public private(set) var isVisible: Bool = false

    private let lock = NSLock()
    private var rawActiveIndicator: NotchIndicatorType? = nil
    private var rawCurrentLevel: Float = 0.0
    private var rawIsVisible: Bool = false

    public var isIndicatorVisible: Bool {
        lock.lock()
        defer { lock.unlock() }
        return rawIsVisible
    }

    public var synchronousLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return rawCurrentLevel
    }

    public var synchronousIndicator: NotchIndicatorType? {
        lock.lock()
        defer { lock.unlock() }
        return rawActiveIndicator
    }

    private var dismissTask: Task<Void, Never>?
    private var isListening: Bool = false

    // State tracking to prevent false triggers on startup / identical reads
    private var lastReportedVolume: Float = -1.0
    private var lastReportedMuted: Bool = false
    private var lastReportedBrightness: Float = -1.0
    private var hasInitializedVolume: Bool = false
    private var hasInitializedBrightness: Bool = false

    // Event monitoring & adaptive polling
    private var globalEventMonitor: Any?
    private var burstTimer: Timer?
    private var burstEndTime: Date = .distantPast

    // CoreAudio device reference
    private var currentOutputDeviceID: AudioDeviceID = 0

    public init() {}

    // MARK: - Lifecycle

    public func start() {
        lock.lock()
        guard !isListening else {
            lock.unlock()
            return
        }
        isListening = true
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupCoreAudioVolumeListener()
            self.setupBrightnessMonitoring()
            self.setupSystemDefinedEventMonitor()

            // Initial silent synchronization (so first change triggers correctly)
            self.syncCurrentVolume(silent: true)
            self.syncCurrentBrightness(silent: true)
        }
    }

    public func stop() {
        lock.lock()
        guard isListening else {
            lock.unlock()
            return
        }
        isListening = false
        rawIsVisible = false
        rawActiveIndicator = nil
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let monitor = self.globalEventMonitor {
                NSEvent.removeMonitor(monitor)
                self.globalEventMonitor = nil
            }

            self.burstTimer?.invalidate()
            self.burstTimer = nil

            DistributedNotificationCenter.default().removeObserver(self)

            self.dismissTask?.cancel()
            self.dismissTask = nil
            self.isVisible = false
            self.activeIndicator = nil
        }
    }

    private func setSynchronousState(indicator: NotchIndicatorType?, level: Float, visible: Bool) {
        lock.lock()
        self.rawActiveIndicator = indicator
        self.rawCurrentLevel = level
        self.rawIsVisible = visible
        lock.unlock()
    }

    // MARK: - Core Public API

    public func updateVolume(level: Float, isMuted: Bool) {
        let effectiveLevel = isMuted ? 0.0 : max(0.0, min(1.0, level))

        lock.lock()
        guard hasInitializedVolume else {
            hasInitializedVolume = true
            lastReportedVolume = effectiveLevel
            lastReportedMuted = isMuted
            lock.unlock()
            return
        }

        let delta = abs(effectiveLevel - lastReportedVolume)
        let muteChanged = (isMuted != lastReportedMuted)

        guard delta > 0.005 || muteChanged else {
            lock.unlock()
            return
        }

        lastReportedVolume = effectiveLevel
        lastReportedMuted = isMuted
        lock.unlock()

        presentIndicator(type: .volume, level: effectiveLevel)
    }

    public func updateBrightness(level: Float) {
        let clamped = max(0.0, min(1.0, level))

        lock.lock()
        guard hasInitializedBrightness else {
            hasInitializedBrightness = true
            lastReportedBrightness = clamped
            lock.unlock()
            return
        }

        let delta = abs(clamped - lastReportedBrightness)
        guard delta > 0.005 else {
            lock.unlock()
            return
        }

        lastReportedBrightness = clamped
        lock.unlock()

        presentIndicator(type: .brightness, level: clamped)
    }

    /// Presents or updates the single under-notch progress bar
    public func presentIndicator(type: NotchIndicatorType, level: Float) {
        setSynchronousState(indicator: type, level: level, visible: true)

        let updateUI = { [weak self] in
            guard let self = self else { return }

            // 1. Immediately dismiss any competing media title banner
            MediaController.shared.dismissTitleBanner()

            // 2. Set active indicator and level
            self.activeIndicator = type
            self.currentLevel = level

            // 3. Make visible with spring animation
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                self.isVisible = true
            }

            // 4. Reset cancellable inactivity debounce timer (1.2 seconds)
            self.dismissTask?.cancel()
            self.dismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    self?.dismissAnimated()
                }
            }
        }

        if Thread.isMainThread {
            updateUI()
        } else {
            DispatchQueue.main.async(execute: updateUI)
        }
    }

    @MainActor
    private func dismissAnimated() {
        setSynchronousState(indicator: nil, level: self.rawCurrentLevel, visible: false)

        withAnimation(.easeInOut(duration: 0.22)) {
            self.isVisible = false
            self.activeIndicator = nil
        }
    }

    // MARK: - CoreAudio Volume Observation

    private func setupCoreAudioVolumeListener() {
        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDevAddr,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.handleDefaultOutputDeviceChanged()
        }

        handleDefaultOutputDeviceChanged()
    }

    private func handleDefaultOutputDeviceChanged() {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != 0 else { return }
        self.currentOutputDeviceID = deviceID

        registerVolumePropertyListeners(for: deviceID)
        syncCurrentVolume(silent: !hasInitializedVolume)
    }

    private func registerVolumePropertyListeners(for deviceID: AudioDeviceID) {
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(deviceID, &volAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.syncCurrentVolume(silent: false)
        }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.syncCurrentVolume(silent: false)
        }
    }

    private func syncCurrentVolume(silent: Bool) {
        guard currentOutputDeviceID != 0 else { return }

        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let volStatus = AudioObjectGetPropertyData(
            currentOutputDeviceID,
            &volAddr,
            0,
            nil,
            &size,
            &volume
        )

        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        _ = AudioObjectGetPropertyData(
            currentOutputDeviceID,
            &muteAddr,
            0,
            nil,
            &muteSize,
            &mute
        )

        let isMuted = (mute != 0)

        if volStatus == noErr {
            if silent {
                lock.lock()
                hasInitializedVolume = true
                lastReportedVolume = isMuted ? 0.0 : max(0.0, min(1.0, volume))
                lastReportedMuted = isMuted
                lock.unlock()
            } else {
                updateVolume(level: volume, isMuted: isMuted)
            }
        }
    }

    // MARK: - Display Brightness Observation

    private func setupBrightnessMonitoring() {
        let distCenter = DistributedNotificationCenter.default()
        distCenter.addObserver(
            self,
            selector: #selector(handleBrightnessNotification),
            name: NSNotification.Name("com.apple.ambientDisplayHardwareEvent"),
            object: nil
        )
        distCenter.addObserver(
            self,
            selector: #selector(handleBrightnessNotification),
            name: NSNotification.Name("com.apple.BezelServices.BMDisplay"),
            object: nil
        )
    }

    @objc private func handleBrightnessNotification() {
        syncCurrentBrightness(silent: false)
    }

    private func setupSystemDefinedEventMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard event.subtype.rawValue == 8 else { return } // 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS
            let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
            let keyFlags = (event.data1 & 0x0000FFFF)
            let isKeyDown = (((keyFlags & 0xFF00) >> 8) == 0xA) // 0xA = key down

            guard isKeyDown else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch keyCode {
                case 2, 3: // NX_KEYTYPE_BRIGHTNESS_UP, NX_KEYTYPE_BRIGHTNESS_DOWN
                    self.triggerBrightnessAdjustmentBurst()
                case 0, 1, 7: // NX_KEYTYPE_SOUND_UP, NX_KEYTYPE_SOUND_DOWN, NX_KEYTYPE_MUTE
                    self.syncCurrentVolume(silent: false)
                default:
                    break
                }
            }
        }
    }

    private func triggerBrightnessAdjustmentBurst() {
        burstEndTime = Date().addingTimeInterval(1.6)

        // Immediate check
        syncCurrentBrightness(silent: false)

        guard burstTimer == nil else { return }

        // Adaptive high-frequency burst polling during active keyboard adjustment
        burstTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if Date() < self.burstEndTime {
                self.syncCurrentBrightness(silent: false)
            } else {
                timer.invalidate()
                self.burstTimer = nil
            }
        }
    }

    private func syncCurrentBrightness(silent: Bool) {
        guard let current = queryDisplayServicesBrightness() else { return }

        if silent {
            lock.lock()
            hasInitializedBrightness = true
            lastReportedBrightness = current
            lock.unlock()
        } else {
            updateBrightness(level: current)
        }
    }

    private func queryDisplayServicesBrightness() -> Float? {
        let displayID = CGMainDisplayID()
        var current: Float = 0

        guard let handle = DisplayServicesBridge.handle,
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else {
            return nil
        }
        typealias Fn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        let res = fn(displayID, &current)
        if res == 0 {
            return max(0.0, min(1.0, current))
        }
        return nil
    }

    // MARK: - Testing and Simulation Helpers

    public func simulateVolumeChange(level: Float, isMuted: Bool = false) {
        lock.lock()
        hasInitializedVolume = true
        lastReportedVolume = -1.0
        lock.unlock()
        updateVolume(level: level, isMuted: isMuted)
    }

    public func simulateBrightnessChange(level: Float) {
        lock.lock()
        hasInitializedBrightness = true
        lastReportedBrightness = -1.0
        lock.unlock()
        updateBrightness(level: level)
    }

    public func resetForTesting() {
        lock.lock()
        rawIsVisible = false
        rawActiveIndicator = nil
        rawCurrentLevel = 0.0
        lastReportedVolume = -1.0
        lastReportedBrightness = -1.0
        lastReportedMuted = false
        hasInitializedVolume = false
        hasInitializedBrightness = false
        lock.unlock()

        if Thread.isMainThread {
            self.isVisible = false
            self.activeIndicator = nil
            self.currentLevel = 0.0
        } else {
            DispatchQueue.main.sync {
                self.isVisible = false
                self.activeIndicator = nil
                self.currentLevel = 0.0
            }
        }
    }
}

// Dynamic loader cache for DisplayServices
private enum DisplayServicesBridge {
    static let handle: UnsafeMutableRawPointer? = {
        let paths = [
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices"
        ]
        for p in paths {
            if let h = dlopen(p, RTLD_LAZY) {
                return h
            }
        }
        return nil
    }()
}
