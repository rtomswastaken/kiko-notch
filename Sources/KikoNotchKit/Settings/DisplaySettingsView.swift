import SwiftUI
import AppKit

/// Display selection and non-notch positioning settings tab
public struct DisplaySettingsView: View {
    @ObservedObject public var displayManager = DisplayManager.shared
    @ObservedObject public var settings = SettingsManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                // Display Selection Picker
                Picker("Target Display", selection: Binding(
                    get: { settings.preferredScreenIndex },
                    set: { index in
                        displayManager.selectScreen(at: index)
                    }
                )) {
                    ForEach(0..<displayManager.screens.count, id: \.self) { idx in
                        let screen = displayManager.screens[idx]
                        Text("\(displayManager.displayName(for: screen))\(idx == 0 ? " (Main)" : "")")
                            .tag(idx)
                    }
                }
                
                // Active Display Diagnostics
                let screen = displayManager.activeScreen
                LabeledContent("Display Resolution", value: "\(Int(screen.frame.width)) × \(Int(screen.frame.height)) pt")
                LabeledContent("Retina Scale Factor", value: String(format: "%.1f×", screen.backingScaleFactor))
                LabeledContent("Hardware Notch", value: displayManager.hasPhysicalNotch ? "Detected" : "None (Simulated Pill)")
            } header: {
                Text("Target Display")
                    .font(.headline)
            }
            
            // Non-notch pill configuration (NOTCH-004)
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Top Bezel Offset")
                        Spacer()
                        Text("\(Int(themeManager.geometry.nonNotchOffsetY)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $themeManager.geometry.nonNotchOffsetY,
                        in: IslandGeometry.minNonNotchOffsetY...IslandGeometry.maxNonNotchOffsetY,
                        step: 1
                    )
                }
                .help("Adjust the vertical offset of the floating pill on Macs without a physical notch.")
            } header: {
                Text("Floating Pill Position (Non-Notch Displays)")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}
