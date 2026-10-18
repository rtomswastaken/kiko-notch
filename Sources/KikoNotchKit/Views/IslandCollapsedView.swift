import SwiftUI
import AppKit

/// Collapsed minimal presentation nestled seamlessly around hardware notch or top screen bezel
public struct IslandCollapsedView: View {
    @ObservedObject public var mediaController = MediaController.shared
    @ObservedObject public var displayManager = DisplayManager.shared
    @ObservedObject public var interactionManager = InteractionManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    
    public var mode: IslandPresentationMode
    public var isHovered: Bool
    
    public init(
        mode: IslandPresentationMode = DisplayManager.shared.presentationMode,
        isHovered: Bool = false
    ) {
        self.mode = mode
        self.isHovered = isHovered
    }
    
    private var isPlaying: Bool {
        mediaController.currentMedia.isPlaying
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Left Wing: Artwork or Notch Logo
            if isPlaying {
                if let thumb = mediaController.currentMedia.artworkImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                        .accessibilityLabel("Playing: \(mediaController.currentMedia.displayTitle)")
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
            } else {
                BrandAssets.MonochromeLogoView(size: 11, color: themeManager.primaryTextColor)
            }
            
            Spacer(minLength: 4)
            
            // Right Wing: Visualizer or minimal status indicator
            if isPlaying {
                AudioVisualizerView(
                    isPlaying: true,
                    barCount: 3,
                    barWidth: 2,
                    maxHeight: 10,
                    color: .accentColor
                )
            } else {
                Circle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            interactionManager.handleSingleClick()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isPlaying ? "Kiko Notch: Playing \(mediaController.currentMedia.displayTitle) by \(mediaController.currentMedia.displayArtist)" : "Kiko Notch Collapsed Island")
        .accessibilityHint("Hover or click to expand")
    }
}
