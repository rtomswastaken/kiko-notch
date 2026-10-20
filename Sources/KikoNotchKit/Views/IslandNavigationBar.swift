//
//  IslandNavigationBar.swift
//  KikoNotchKit
//
//  Fixed-position, stationary header bar for the expanded Kiko Notch Island.
//  Places the Kiko Notch title and compact navigation selector on the left (clear of the physical notch),
//  maintains an unobstructed center space beneath the notch, and provides date, battery, pin, and collapse on the right.
//

import SwiftUI
import AppKit

public struct IslandNavigationBar: View {
    @ObservedObject public var navigation = IslandNavigationModel.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var batteryMonitor = BatteryMonitor.shared
    @ObservedObject public var accentTheme = AccentThemeManager.shared
    @Binding public var isPinned: Bool
    public var onCollapse: () -> Void

    @State private var isHoveringSettings = false
    @State private var isHoveringPin = false
    @State private var isHoveringCollapse = false

    public init(
        isPinned: Binding<Bool>,
        onCollapse: @escaping () -> Void
    ) {
        self._isPinned = isPinned
        self.onCollapse = onCollapse
    }

    private var formattedDate: String {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df.string(from: Date()).uppercased()
    }

    private var batteryIcon: String {
        let pct = batteryMonitor.currentState.percentage
        if batteryMonitor.currentState.isCharging {
            return "battery.100.bolt"
        }
        if pct >= 85 { return "battery.100" }
        if pct >= 60 { return "battery.75" }
        if pct >= 35 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 1. Leading Section: Brand Mark & Navigation Selector
            // Positioned to the left of the physical MacBook notch (x <= 195 pt, notch starts at x = 228 pt)
            HStack(spacing: 6) {
                // Official Kiko Notch Logo
                BrandAssets.MonochromeLogoView(size: 14)

                Text(BrandAssets.appName.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white)
                    .tracking(0.5)
                    .lineLimit(1)

                // Compact Shared Navigation Selector Strip (Excluding Settings)
                HStack(spacing: 2) {
                    ForEach(IslandTab.pageTabs) { tab in
                        tabButton(for: tab)
                    }
                }
                .padding(2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
            .frame(maxWidth: 195, alignment: .leading)

            // 2. Center Safe Zone: Clear of the physical MacBook hardware notch
            // Guarantees no interactive content or text sits behind the notch (notch width <= 224 pt)
            Spacer(minLength: 236)

            // 3. Trailing Section: Date, Battery, Settings, Pin & Collapse
            // Positioned to the right of the physical MacBook notch (notch ends at x = 452 pt)
            HStack(spacing: 5) {
                // Live Date
                Text(formattedDate)
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)

                // Real Battery Indicator
                HStack(spacing: 3) {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 8.5))
                        .foregroundColor(batteryMonitor.currentState.isCharging ? .green : (batteryMonitor.currentState.percentage < 20 ? .red : Color.white))

                    Text("\(batteryMonitor.currentState.percentage)%")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white)
                }
                .padding(.horizontal, 4.5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )

                // Settings Gear Button
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 9.5))
                        .foregroundColor(isHoveringSettings ? Color.white : Color.white.opacity(0.75))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isHoveringSettings ? 0.14 : 0.04))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { isHoveringSettings = $0 }
                .help("Open Settings")
                .accessibilityLabel("Open Settings")

                // Pin Island Open Button
                Button(action: {
                    isPinned.toggle()
                }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 9.5))
                        .foregroundColor(isPinned ? Color.white : (isHoveringPin ? Color.white : Color.white.opacity(0.75)))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isPinned ? 0.16 : (isHoveringPin ? 0.10 : 0.04)))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { isHoveringPin = $0 }
                .help(isPinned ? "Unpin Island" : "Pin Island Open")
                .accessibilityLabel(isPinned ? "Unpin Island" : "Pin Island Open")

                // Collapse Island Button
                Button(action: onCollapse) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isHoveringCollapse ? Color.white : Color.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isHoveringCollapse ? 0.10 : 0.04))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCollapse = $0 }
                .help("Collapse Island")
                .accessibilityLabel("Collapse Island")
            }
            .frame(maxWidth: 195, alignment: .trailing)
        }
        .frame(height: IslandSpacing.navBarHeight)
    }

    @ViewBuilder
    private func tabButton(for tab: IslandTab) -> some View {
        let isActive = navigation.activeTab == tab
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                navigation.selectTab(tab)
            }
        }) {
            ZStack {
                if isActive {
                    Capsule()
                        .fill(accentTheme.isDefaultWhite ? Color.white.opacity(0.22) : accentTheme.primaryAccent.opacity(0.25))
                        .background(
                            Capsule()
                                .fill(accentTheme.subtleBackgroundGradient)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(accentTheme.isDefaultWhite ? Color.white.opacity(0.24) : accentTheme.primaryAccent.opacity(0.45), lineWidth: 0.6)
                        )
                }

                Image(systemName: tab.iconName)
                    .font(.system(size: 9, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? (accentTheme.isDefaultWhite ? .white : accentTheme.primaryAccent) : Color.white.opacity(0.70))
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .accessibilityLabel(tab.title)
    }
}
