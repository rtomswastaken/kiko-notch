import SwiftUI
import ServiceManagement

/// General application preferences tab
public struct GeneralSettingsView: View {
    @ObservedObject public var settings = SettingsManager.shared
    @ObservedObject public var lifecycle = AppLifecycle.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                // Launch at Login via SMAppService
                Toggle("Launch Kiko Notch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { enabled in
                        settings.launchAtLogin = enabled
                        applyLaunchAtLogin(enabled)
                    }
                ))
                .accessibilityLabel("Launch Kiko Notch at Login")
                
                // Show in Dock vs Menu-bar-only
                Toggle("Show icon in Dock", isOn: $lifecycle.showInDock)
                    .accessibilityLabel("Show Kiko Notch icon in Dock")
                
                // Screen Capture Exclusion (CORE-010)
                Toggle("Exclude Island from Screen Capture & Recordings", isOn: $settings.hideFromScreenCapture)
                    .accessibilityLabel("Exclude Island from Screen Capture")
                    .help("When enabled, screenshots and screen recordings will not capture the floating island.")
            } header: {
                Text("Startup & Visibility")
                    .font(.headline)
            }
            
            Section {
                // Hover expand delay
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Hover Expand Delay")
                        Spacer()
                        Text("\(settings.hoverDelayMs) ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.hoverDelayMs) },
                            set: { settings.hoverDelayMs = Int($0) }
                        ),
                        in: 50...600,
                        step: 50
                    )
                }
                .accessibilityLabel("Hover expand delay \(settings.hoverDelayMs) milliseconds")
                
                // Auto collapse delay
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Mouse Exit Collapse Delay")
                        Spacer()
                        Text("\(settings.collapseDelayMs) ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.collapseDelayMs) },
                            set: { settings.collapseDelayMs = Int($0) }
                        ),
                        in: 100...1000,
                        step: 50
                    )
                }
                .accessibilityLabel("Mouse exit collapse delay \(settings.collapseDelayMs) milliseconds")
            } header: {
                Text("Interaction Delays")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
    
    private func applyLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[Kiko Notch] Error updating SMAppService: \(error.localizedDescription)")
            }
        }
    }
}
