import Foundation
import CoreGraphics

/// Visual presentation states for the Kiko Notch Island
public enum IslandDisplayState: String, CaseIterable, Codable, Sendable {
    case collapsed
    case peek
    case expanded
    case pinned
}

/// Hardware presentation mode
public enum IslandPresentationMode: Sendable, Equatable {
    case physicalNotch(notchRect: CGRect)
    case nonNotchFloatingPill(pillRect: CGRect)
}

/// Active transient HUD or Banner event
public enum SystemHUDEvent: Sendable, Equatable {
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case keyboardBacklight(level: Float)
    case audioOutputChanged(deviceName: String)
    case batteryStatus(percentage: Int, isCharging: Bool, timeRemainingMinutes: Int?)
    case bluetoothDevice(name: String, isConnected: Bool, batteryLevel: Int?)
    case downloadProgress(filename: String, progress: Double, isComplete: Bool)
}
