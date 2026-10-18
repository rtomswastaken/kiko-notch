import SwiftUI
import AppKit

/// Appearance and theme customization preferences tab
public struct AppearanceSettingsView: View {
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var settings = SettingsManager.shared
    
    @State private var showingExportAlert = false
    @State private var exportSuccess = false
    @State private var showingResetAlert = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                // Theme Preset Picker
                Picker("Theme Preset", selection: $themeManager.currentTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                
                // Reduced Motion Toggle (CUSTOM-006)
                Toggle("Reduce Motion (Disable Spring Animations)", isOn: Binding(
                    get: { themeManager.isReducedMotion },
                    set: { themeManager.setReducedMotionPreference($0) }
                ))
                .accessibilityLabel("Reduce Motion toggle")
            } header: {
                Text("Theme Selection")
                    .font(.headline)
            }
            
            Section {
                // Background Opacity
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Background Opacity")
                        Spacer()
                        Text("\(Int(themeManager.colors.backgroundOpacity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $themeManager.colors.backgroundOpacity, in: 0.3...1.0, step: 0.05)
                }
                
                // Blur Intensity
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Blur Intensity")
                        Spacer()
                        Text("\(Int(themeManager.colors.blurIntensity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $themeManager.colors.blurIntensity, in: 0.2...1.0, step: 0.05)
                }
                
                // Frost Intensity
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Frost Texture Intensity")
                        Spacer()
                        Text("\(Int(themeManager.colors.frostIntensity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $themeManager.colors.frostIntensity, in: 0.0...1.0, step: 0.05)
                }
            } header: {
                Text("Liquid Glass Materials")
                    .font(.headline)
            }
            
            Section {
                // Corner Radius
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Corner Radius")
                        Spacer()
                        Text("\(Int(themeManager.geometry.cornerRadius)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $themeManager.geometry.cornerRadius,
                        in: IslandGeometry.minCornerRadius...IslandGeometry.maxCornerRadius,
                        step: 1
                    )
                }
                
                // Expanded Dimensions
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expanded Width: \(Int(themeManager.geometry.expandedWidth)) pt")
                            .font(.system(size: 11))
                        Slider(
                            value: $themeManager.geometry.expandedWidth,
                            in: IslandGeometry.minExpandedWidth...IslandGeometry.maxExpandedWidth,
                            step: 10
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expanded Height: \(Int(themeManager.geometry.expandedHeight)) pt")
                            .font(.system(size: 11))
                        Slider(
                            value: $themeManager.geometry.expandedHeight,
                            in: IslandGeometry.minExpandedHeight...IslandGeometry.maxExpandedHeight,
                            step: 10
                        )
                    }
                }
            } header: {
                Text("Geometry & Proportions")
                    .font(.headline)
            }
            
            Section {
                // Layout Builder Module Ordering & Toggles (CUSTOM-005)
                ForEach(LayoutConfiguration.ModuleSlot.allCases, id: \.self) { slot in
                    Toggle(slot.rawValue, isOn: Binding(
                        get: { themeManager.layout.visibleModules.contains(slot) },
                        set: { _ in themeManager.layout.toggleVisibility(for: slot) }
                    ))
                }
            } header: {
                Text("Expanded Island Modules")
                    .font(.headline)
            }
            
            Section {
                // Export / Import / Reset (CUSTOM-007)
                HStack(spacing: 12) {
                    Button("Export Theme…") {
                        exportThemeToFile()
                    }
                    
                    Button("Import Theme…") {
                        importThemeFromFile()
                    }
                    
                    Spacer()
                    
                    Button("Reset to Defaults", role: .destructive) {
                        themeManager.resetToDefaults()
                    }
                }
            } header: {
                Text("Theme Management")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
    
    private func exportThemeToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "kiko_theme.json"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let profile = themeManager.currentProfile()
                try? ThemeStorage.exportTheme(profile: profile, to: url)
            }
        }
    }
    
    private func importThemeFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url,
               let profile = try? ThemeStorage.importTheme(from: url) {
                themeManager.loadProfile(profile)
            }
        }
    }
}
