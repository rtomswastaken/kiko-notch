//
//  AudioVisualizerView.swift
//  KikoNotchKit
//
//  Responsive 3-bar audio visualizer reacting to genuine audio signal levels
//  with multi-color gradient spectrum support and zero idle CPU when paused.
//

import SwiftUI

public struct AudioVisualizerView: View {
    public var isPlaying: Bool
    public var barCount: Int
    public var barWidth: CGFloat
    public var maxHeight: CGFloat
    public var color: Color?
    public var colors: [Color]?

    @ObservedObject private var signalMonitor = AudioSignalMonitor.shared
    @ObservedObject private var accentTheme = AccentThemeManager.shared

    public init(
        isPlaying: Bool,
        barCount: Int = 3,
        barWidth: CGFloat = 2.5,
        maxHeight: CGFloat = 12.0,
        color: Color? = nil,
        colors: [Color]? = nil
    ) {
        self.isPlaying = isPlaying
        self.barCount = barCount
        self.barWidth = barWidth
        self.maxHeight = maxHeight
        self.color = color
        self.colors = colors
    }

    private let minBarHeight: CGFloat = 2.5

    private func heightForBar(at index: Int) -> CGFloat {
        guard isPlaying else { return minBarHeight }
        let levels = signalMonitor.barLevels
        let normalized: CGFloat = index < levels.count ? levels[index] : 0.15
        let clamped = max(0.0, min(1.0, normalized))
        return minBarHeight + (maxHeight - minBarHeight) * clamped
    }

    private func colorForBar(at index: Int) -> Color {
        if let explicitColors = colors, index < explicitColors.count {
            return explicitColors[index]
        }
        if let explicitColor = color {
            return explicitColor
        }
        let themeColors = accentTheme.colors
        if index < themeColors.count {
            return themeColors[index]
        }
        return accentTheme.primaryAccent
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { idx in
                RoundedRectangle(cornerRadius: barWidth / 2.0)
                    .fill(colorForBar(at: idx))
                    .frame(width: barWidth, height: heightForBar(at: idx))
                    .animation(
                        .spring(response: 0.18, dampingFraction: 0.75, blendDuration: 0),
                        value: signalMonitor.barLevels
                    )
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "Audio visualizer playing (RMS: \(Int(signalMonitor.rmsLevel * 100))%)" : "Audio paused")
    }
}
