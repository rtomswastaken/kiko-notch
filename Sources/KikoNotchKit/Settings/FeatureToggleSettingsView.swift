import SwiftUI

/// Settings view providing master enable/disable toggles for all modular Kiko Notch features.
/// Implements SET-005.
public struct FeatureToggleSettingsView: View {
    @ObservedObject public var settings = SettingsManager.shared
    @ObservedObject public var featureRegistry = FeatureRegistry.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Dynamic Island Modules")) {
                ForEach(KikoFeatureID.allCases, id: \.self) { feature in
                    Toggle(displayName(for: feature), isOn: Binding(
                        get: { settings.isFeatureEnabled(feature) },
                        set: { isEnabled in
                            featureRegistry.setModuleEnabled(feature, enabled: isEnabled)
                        }
                    ))
                }
            }
            
            Section {
                Button("Reset All Features to Enabled") {
                    for feature in KikoFeatureID.allCases {
                        if !settings.isFeatureEnabled(feature) {
                            featureRegistry.setModuleEnabled(feature, enabled: true)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func displayName(for feature: KikoFeatureID) -> String {
        switch feature {
        case .media: return "Music & Media Controls"
        case .fileShelf: return "File Shelf & Drag-and-Drop"
        case .systemHUD: return "System HUD (Volume, Brightness, Audio)"
        case .battery: return "Battery Status & Low Warnings"
        case .bluetooth: return "Bluetooth Device Monitor"
        case .calendar: return "Calendar Agenda & Next Event"
        case .reminders: return "Reminders Integration"
        case .notifications: return "Notification Center & In-Island Alerts"
        case .weather: return "Weather & Forecast"
        case .downloads: return "Browser Download Monitoring"
        case .clipboard: return "Clipboard History & Actions"
        case .aiDashboard: return "AI Intelligence Dashboard"
        case .customActions: return "Customizable Function Buttons"
        case .systemMetrics: return "System Metrics & Live Telemetry"
        }
    }
}
