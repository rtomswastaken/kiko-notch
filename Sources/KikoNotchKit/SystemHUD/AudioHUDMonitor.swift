import Foundation
import CoreAudio
import AudioToolbox

/// CoreAudio Event-driven listener for Volume and Output Route changes.
/// Implements SYS-001, SYS-004, and PERF-003 (zero-polling, event-driven).
public final class AudioHUDMonitor: @unchecked Sendable {
    public static let shared = AudioHUDMonitor()
    
    public var onVolumeChange: (@Sendable (Float, Bool) -> Void)?
    public var onOutputDeviceChange: (@Sendable (String) -> Void)?
    
    private var defaultOutputDeviceID: AudioDeviceID = 0
    private var isListening: Bool = false
    
    public init() {}
    
    public func start() {
        guard !isListening else { return }
        isListening = true
        
        setupDefaultDeviceListener()
        registerDeviceListeners()
    }
    
    public func stop() {
        guard isListening else { return }
        isListening = false
        // Listeners deregistration
    }
    
    private func setupDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
        
        handleDefaultDeviceChanged()
    }
    
    private func handleDefaultDeviceChanged() {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        guard status == noErr, deviceID != 0 else { return }
        self.defaultOutputDeviceID = deviceID
        
        let deviceName = getDeviceName(deviceID: deviceID)
        onOutputDeviceChange?(deviceName)
        
        registerDeviceListeners()
    }
    
    private func registerDeviceListeners() {
        guard defaultOutputDeviceID != 0 else { return }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            defaultOutputDeviceID,
            &volumeAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.queryCurrentVolume()
        }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            defaultOutputDeviceID,
            &muteAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.queryCurrentVolume()
        }
    }
    
    public func queryCurrentVolume() {
        guard defaultOutputDeviceID != 0 else { return }
        
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let volStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &volumeAddress,
            0,
            nil,
            &size,
            &volume
        )
        
        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        _ = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &muteAddress,
            0,
            nil,
            &muteSize,
            &mute
        )
        
        if volStatus == noErr {
            onVolumeChange?(volume, mute == 1)
        }
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameString: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        
        let status = withUnsafeMutablePointer(to: &nameString) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &size,
                ptr
            )
        }
        
        if status == noErr {
            return nameString as String
        }
        return "Audio Output"
    }
}
