//
//  IslandCollapsedView.swift
//  KikoNotchKit
//
//  Collapsed minimal presentation nestled seamlessly around hardware notch or top screen bezel.
//  When media is playing, wings extend outside the physical notch displaying artwork on the left
//  and a live 3-bar audio visualizer on the right.
//

import SwiftUI
import AppKit

public struct IslandCollapsedView: View {
    @ObservedObject public var mediaController = MediaController.shared
    @ObservedObject public var displayManager = DisplayManager.shared
    @ObservedObject public var interactionManager = InteractionManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var accentTheme = AccentThemeManager.shared
    @ObservedObject public var indicatorManager = NotchIndicatorManager.shared

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

    private var hardwareNotchWidth: CGFloat {
        IslandGeometry.getClosedNotchSize(for: displayManager.targetScreen).width
    }

    private var baseNotchHeight: CGFloat {
        IslandGeometry.getClosedNotchSize(for: displayManager.targetScreen).height
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Top Bar (Wing items aligned with physical notch bezel)
            HStack(spacing: 0) {
                // Left Wing: Artwork or Notch Logo
                HStack {
                    if isPlaying {
                        if let thumb = mediaController.currentMedia.artworkImage {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(accentTheme.borderGradient, lineWidth: 0.8)
                                )
                        } else {
                            Image(systemName: mediaController.currentMedia.playerApp.contains("YouTube") ? "play.rectangle.fill" : "music.note")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accentTheme.linearGradient)
                        }
                    } else {
                        BrandAssets.MonochromeLogoView(size: 11, color: themeManager.primaryTextColor)
                    }
                }
                .frame(width: isPlaying ? 40 : 20, alignment: .center)
                .padding(.leading, isPlaying ? 8 : 10)

                // Center Spacer: Keeps physical hardware notch completely unobstructed!
                Spacer(minLength: isPlaying ? hardwareNotchWidth - 16 : 8)

                // Right Wing: Exactly 3-Bar Audio Visualizer with multi-color gradient
                HStack {
                    if isPlaying {
                        AudioVisualizerView(
                            isPlaying: true,
                            barCount: 3,
                            barWidth: 2.2,
                            maxHeight: 11,
                            colors: accentTheme.colors
                        )
                    } else {
                        Circle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(width: isPlaying ? 40 : 20, alignment: .center)
                .padding(.trailing, isPlaying ? 8 : 10)
            }
            .frame(height: baseNotchHeight)

            // Under-Notch Presentation Slot (Contextual Indicator or Media Title Announcement)
            if indicatorManager.isVisible {
                HStack {
                    Spacer()
                    NotchProgressBarView(level: indicatorManager.currentLevel)
                    Spacer()
                }
                .frame(height: 22)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -4)),
                    removal: .opacity
                ))
            } else if mediaController.isShowingTitleBanner && isPlaying {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentTheme.horizontalGradient)
                        .frame(width: 4.5, height: 4.5)

                    Text(mediaController.currentMedia.displayTitle)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.6))

                    Text(mediaController.currentMedia.displayArtist)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(accentTheme.linearGradient)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .frame(height: 28)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -4)),
                    removal: .opacity
                ))
            }
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isPlaying ? "Kiko Notch: Playing \(mediaController.currentMedia.displayTitle) by \(mediaController.currentMedia.displayArtist)" : "Kiko Notch Collapsed Island")
        .accessibilityHint("Hover or click to expand")
    }
}
