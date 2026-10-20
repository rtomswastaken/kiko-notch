//
//  HomeHeaderView.swift
//  KikoNotchKit
//
//  Compact header for the Kiko Notch Home page featuring the official logo,
//  local time-of-day greeting, current date, and accurate battery status.
//

import SwiftUI
import AppKit

public struct HomeHeaderView: View {
    @ObservedObject public var batteryMonitor = BatteryMonitor.shared
    @ObservedObject public var themeManager = ThemeManager.shared

    public init() {}

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning!"
        case 12..<17:
            return "Good afternoon!"
        case 17..<22:
            return "Good evening!"
        default:
            return "Good night!"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: Date()).uppercased()
    }

    private var batteryState: BatteryState {
        batteryMonitor.currentState
    }

    private var batteryIconName: String {
        guard batteryState.hasBattery else {
            return "powerplug.fill"
        }
        if batteryState.isCharging {
            return "bolt.fill"
        }
        let pct = batteryState.percentage
        if pct >= 85 { return "battery.100" }
        if pct >= 60 { return "battery.75" }
        if pct >= 35 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Left: Logo and Greeting
            HStack(spacing: 8) {
                BrandAssets.MonochromeLogoView(size: 18, color: themeManager.primaryTextColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text("KIKO NOTCH")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.primaryTextColor)
                        .tracking(0.5)

                    Text(greetingText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.85))
                }
            }

            Spacer(minLength: 8)

            // Right: Date and Battery Indicator
            HStack(spacing: 8) {
                Text(formattedDate)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))

                // Battery Capsule
                HStack(spacing: 5) {
                    Image(systemName: batteryIconName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(batteryState.isCharging ? .green : (batteryState.hasBattery && batteryState.percentage < 20 ? .red : themeManager.primaryTextColor))

                    if batteryState.hasBattery {
                        Text("\(batteryState.percentage)%")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.primaryTextColor)
                    } else {
                        Text("AC Power")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
                )
            }
        }
    }
}
