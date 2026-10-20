import SwiftUI

/// Settings view for System HUD triggers and display durations.
/// Implements SYS-005 with direct reactive binding to SystemHUDManager.
public struct HUDSettingsView: View {
    @ObservedObject public var hudManager = SystemHUDManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Display Duration")
                        Spacer()
                        Text(String(format: "%.1f seconds", hudManager.displayDuration))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $hudManager.displayDuration, in: 0.5...3.5, step: 0.1)
                }
            } header: {
                Text("HUD Timing")
                    .font(.headline)
            }
            
            Section {
                Toggle("Volume Change Indicator", isOn: $hudManager.isVolumeEnabled)
                Toggle("Display Brightness Indicator", isOn: $hudManager.isBrightnessEnabled)
                Toggle("Keyboard Backlight Indicator", isOn: $hudManager.isBacklightEnabled)
                Toggle("Audio Output Route Changes", isOn: $hudManager.isAudioRouteEnabled)
                Toggle("Battery Status & Low Warnings", isOn: $hudManager.isBatteryEnabled)
                Toggle("Bluetooth Device Connections", isOn: $hudManager.isBluetoothEnabled)
                Toggle("Browser Download Progress", isOn: $hudManager.isDownloadsEnabled)
            } header: {
                Text("Active HUD Triggers")
                    .font(.headline)
            } footer: {
                Text("Kiko Notch displays brief floating notch animations when macOS hardware keys or device states change.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}
