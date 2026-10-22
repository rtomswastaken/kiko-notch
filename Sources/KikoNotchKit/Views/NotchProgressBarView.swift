//
//  NotchProgressBarView.swift
//  KikoNotchKit
//
//  Compact contextual progress bar rendered directly beneath the physical MacBook notch.
//  Strictly conforms to the requirement of containing ONLY:
//  - A monochromatic progress-bar track.
//  - A filled portion representing the current level using the shared dynamic accent gradient.
//  - NO icons, NO text, NO percentage, NO slider thumbs, NO extra popups.
//

import SwiftUI

public struct NotchProgressBarView: View {
    @ObservedObject public var accentTheme = AccentThemeManager.shared
    public var level: Float // 0.0 ... 1.0
    public var trackWidth: CGFloat
    public var trackHeight: CGFloat

    public init(
        level: Float,
        trackWidth: CGFloat = 130.0,
        trackHeight: CGFloat = 4.0
    ) {
        self.level = level
        self.trackWidth = trackWidth
        self.trackHeight = trackHeight
    }

    private var clampedLevel: CGFloat {
        CGFloat(max(0.0, min(1.0, level)))
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Subtle monochromatic background track
            Capsule()
                .fill(Color.white.opacity(0.16))
                .frame(width: trackWidth, height: trackHeight)

            // Dynamic gradient fill representing current system volume or brightness level
            Capsule()
                .fill(accentTheme.horizontalGradient)
                .frame(width: max(0, trackWidth * clampedLevel), height: trackHeight)
        }
        .frame(width: trackWidth, height: trackHeight)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("System Level Indicator")
        .accessibilityValue("\(Int(clampedLevel * 100))%")
    }
}
