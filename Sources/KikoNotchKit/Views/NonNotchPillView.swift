import SwiftUI

/// Minimalist floating pill indicator for Macs without a physical notch
public struct NonNotchPillView: View {
    public var isHovered: Bool
    public var isPlaying: Bool
    
    public init(isHovered: Bool = false, isPlaying: Bool = false) {
        self.isHovered = isHovered
        self.isPlaying = isPlaying
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Official monochrome logo glyph
            BrandAssets.MonochromeLogoView(size: 10, color: .primary)
            
            // Subtle activity indicator when playing
            if isPlaying {
                AudioVisualizerView(
                    isPlaying: true,
                    barCount: 3,
                    barWidth: 2,
                    maxHeight: 8,
                    color: .accentColor
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kiko Notch Floating Island Pill")
        .accessibilityHint("Hover or click to expand")
    }
}
