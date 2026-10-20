import SwiftUI
import AppKit

/// Appearance and liquid glass material preferences tab
public struct AppearanceSettingsView: View {
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var settings = SettingsManager.shared

    @State private var showingResetAlert = false

    public init() {}

    public var body: some View {
        Form {
            // MARK: - Theme Preset Selection
            Section {
                Picker("Theme Preset", selection: $themeManager.currentTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Reduce Motion (Disable Spring Animations)", isOn: Binding(
                    get: { themeManager.isReducedMotion },
                    set: { themeManager.setReducedMotionPreference($0) }
                ))
                .accessibilityLabel("Reduce Motion toggle")
            } header: {
                Text("Theme Selection")
                    .font(.headline)
            }

            // MARK: - Liquid Glass Materials
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Background Opacity")
                        Spacer()
                        Text("\(Int(themeManager.colors.backgroundOpacity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $themeManager.colors.backgroundOpacity, in: 0.3...1.0, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Blur Intensity")
                        Spacer()
                        Text("\(Int(themeManager.colors.blurIntensity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $themeManager.colors.blurIntensity, in: 0.2...1.0, step: 0.05)
                }

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

            // MARK: - Island Geometry
            Section {
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

                LabeledContent("Expanded Island Dimensions") {
                    Text("\(Int(IslandGeometry.expandedSize.width)) × \(Int(IslandGeometry.expandedSize.height)) pt")
                        .foregroundColor(.secondary)
                }

                LabeledContent("Collapsed Island Dimensions") {
                    Text("\(Int(IslandGeometry.collapsedSize.width)) × \(Int(IslandGeometry.collapsedSize.height)) pt")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Geometry & Proportions")
                    .font(.headline)
            }

            // MARK: - Dynamic Artwork Accents
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adaptive Artwork-Derived Accents")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Kiko Notch uses a monochrome dark glass base and dynamically extracts vibrant accent gradient highlights from currently playing media artwork.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Accent Highlights")
                    .font(.headline)
            }

            // MARK: - Reset Actions
            Section {
                HStack {
                    Spacer()
                    Button("Reset Appearance to Defaults", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .alert("Reset Appearance Settings?", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                themeManager.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore the default Liquid Glass Dark theme, materials, corner radius, and animation preferences.")
        }
    }
}
