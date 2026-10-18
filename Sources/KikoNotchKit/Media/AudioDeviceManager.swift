import Foundation
import CoreAudio

/// Represents a system audio output device
public struct AudioOutputDevice: Identifiable, Hashable, Sendable {
    public let id: AudioObjectID
    public let name: String
    public let uid: String
    public let isDefault: Bool
    
    public init(id: AudioObjectID, name: String, uid: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.uid = uid
        self.isDefault = isDefault
    }
}

/// Discovers and manages macOS CoreAudio output devices
public final class AudioDeviceManager: ObservableObject, @unchecked Sendable {
    public static let shared = AudioDeviceManager()
    
    @Published public private(set) var outputDevices: [AudioOutputDevice] = []
    @Published public private(set) var defaultOutputDevice: AudioOutputDevice?
    
    private init() {
        refreshDevices()
    }
    
    /// Queries CoreAudio to discover all audio devices with output channels
    public func refreshDevices() {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else {
            return
        }
        
        let deviceCount = Int(propertySize / UInt32(MemoryLayout<AudioObjectID>.size))
        var deviceIDs = [AudioObjectID](repeating: 0, count: deviceCount)
        
        let fetchStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        guard fetchStatus == noErr else { return }
        
        let defaultID = getDefaultOutputDeviceID()
        var results: [AudioOutputDevice] = []
        
        for id in deviceIDs {
            // Check if device has output streams
            if hasOutputStreams(deviceID: id) {
                let name = getDeviceName(deviceID: id) ?? "Audio Device (\(id))"
                let uid = getDeviceUID(deviceID: id) ?? "\(id)"
                let isDef = (id == defaultID)
                let dev = AudioOutputDevice(id: id, name: name, uid: uid, isDefault: isDef)
                results.append(dev)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.outputDevices = results
            self.defaultOutputDevice = results.first(where: { $0.isDefault })
        }
    }
    
    /// Sets the system default audio output device
    public func setDefaultOutputDevice(deviceID: AudioObjectID) {
        var id = deviceID
        let propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            propertySize,
            &id
        )
        
        if status == noErr {
            refreshDevices()
        }
    }
    
    // MARK: - Private CoreAudio Helpers
    
    private func getDefaultOutputDeviceID() -> AudioObjectID {
        var deviceID: AudioObjectID = 0
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
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
            &propertySize,
            &deviceID
        )
        
        return status == noErr ? deviceID : 0
    }
    
    private func hasOutputStreams(deviceID: AudioObjectID) -> Bool {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &propertySize
        )
        
        return status == noErr && propertySize > 0
    }
    
    private func getDeviceName(deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var nameCF: CFString?
        var propertySize = UInt32(MemoryLayout<CFString?>.size)
        
        let status = withUnsafeMutablePointer(to: &nameCF) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &propertySize,
                ptr
            )
        }
        
        if status == noErr, let name = nameCF as String? {
            return name
        }
        return nil
    }
    
    private func getDeviceUID(deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var uidCF: CFString?
        var propertySize = UInt32(MemoryLayout<CFString?>.size)
        
        let status = withUnsafeMutablePointer(to: &uidCF) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &propertySize,
                ptr
            )
        }
        
        if status == noErr, let uid = uidCF as String? {
            return uid
        }
        return nil
    }
}
