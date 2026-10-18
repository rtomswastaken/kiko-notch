import SwiftUI

/// Settings view for System HUD triggers and display durations.
/// Implements SYS-005.
public struct HUDSettingsView: View {
    @AppStorage("kiko.hud.duration") private var hudDuration: Double = 1.8
    @AppStorage("kiko.hud.volumeEnabled") private var volumeEnabled: Bool = true
    @AppStorage("kiko.hud.brightnessEnabled") private var brightnessEnabled: Bool = true
    @AppStorage("kiko.hud.backlightEnabled") private var backlightEnabled: Bool = true
    @AppStorage("kiko.hud.audioRouteEnabled") private var audioRouteEnabled: Bool = true
    @AppStorage("kiko.hud.batteryEnabled") private var batteryEnabled: Bool = true
    @AppStorage("kiko.hud.bluetoothEnabled") private var bluetoothEnabled: Bool = true
    @AppStorage("kiko.hud.downloadsEnabled") private var downloadsEnabled: Bool = true
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("HUD Timing")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Display Duration")
                        Spacer()
                        Text(String(format: "%.1f seconds", hudDuration))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $hudDuration, in: 0.5...3.5, step: 0.1)
                }
            }
            
            Section(header: Text("Active HUD Triggers")) {
                Toggle("Volume Change HUD", isOn: $volumeEnabled)
                Toggle("Display Brightness HUD", isOn: $brightnessEnabled)
                Toggle("Keyboard Backlight HUD", isOn: $backlightEnabled)
                Toggle("Audio Output Route Change", isOn: $audioRouteEnabled)
                Toggle("Battery Status & Low Warnings", isOn: $batteryEnabled)
                Toggle("Bluetooth Connect/Disconnect", isOn: $bluetoothEnabled)
                Toggle("Browser Download Progress", isOn: $downloadsEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
