//
//  HomeNowPlayingWidget.swift
//  KikoNotchKit
//
//  Enhanced Now Playing media widget for the Home page upper-left column,
//  supporting Apple Music, Spotify, YouTube browser playback, and a 3-bar visualizer.
//

import SwiftUI
import AppKit

public struct HomeNowPlayingWidget: View {
    @ObservedObject public var mediaController = MediaController.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var accentTheme = AccentThemeManager.shared

    public init() {}

    private var meta: MediaMetadata {
        mediaController.currentMedia
    }

    private var isPlaying: Bool {
        meta.isPlaying
    }

    private var hasMedia: Bool {
        isPlaying || !meta.title.isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Widget Header Row
            HStack(spacing: 5) {
                Image(systemName: "music.note")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isPlaying ? accentTheme.primaryAccent : themeManager.secondaryTextColor)

                Text("NOW PLAYING")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isPlaying ? accentTheme.primaryAccent.opacity(0.9) : themeManager.secondaryTextColor.opacity(0.85))
                    .tracking(0.6)

                if hasMedia && meta.playerApp != "None" {
                    Text(meta.playerApp.uppercased())
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(isPlaying ? accentTheme.primaryAccent : themeManager.primaryTextColor.opacity(0.8))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(isPlaying ? accentTheme.subtleBackgroundGradient : LinearGradient(colors: [Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isPlaying ? accentTheme.borderGradient : LinearGradient(colors: [Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing), lineWidth: 0.5)
                        )
                }

                Spacer()

                // 3-Bar Audio Visualizer with Multi-Color Gradient
                AudioVisualizerView(
                    isPlaying: isPlaying,
                    barCount: 3,
                    barWidth: 2.5,
                    maxHeight: 11,
                    colors: isPlaying ? accentTheme.colors : nil
                )
            }

            if hasMedia {
                // Active Media Composition
                VStack(spacing: 6) {
                    HStack(alignment: .center, spacing: 10) {
                        // Artwork Thumbnail with dynamic accent gradient border
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white.opacity(0.06))

                            if let img = meta.artworkImage {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: meta.playerApp.contains("YouTube") ? "play.rectangle.fill" : "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(accentTheme.linearGradient)
                            }
                        }
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(isPlaying ? accentTheme.borderGradient : LinearGradient(colors: [Color.white.opacity(0.12)], startPoint: .leading, endPoint: .trailing), lineWidth: 0.8)
                        )

                        // Track & Artist Metadata
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meta.displayTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(themeManager.primaryTextColor)
                                .lineLimit(1)

                            Text(meta.displayArtist)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(isPlaying ? accentTheme.secondaryAccent.opacity(0.95) : themeManager.secondaryTextColor)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        // Playback Controls Row
                        HStack(spacing: 6) {
                            Button(action: {
                                if meta.canControl {
                                    mediaController.previousTrack()
                                }
                            }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(meta.canControl ? themeManager.secondaryTextColor : themeManager.secondaryTextColor.opacity(0.25))
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.white.opacity(meta.canControl ? 0.06 : 0.02)))
                            }
                            .buttonStyle(.plain)
                            .disabled(!meta.canControl)
                            .help(meta.canControl ? "Previous Track" : "Playback controls managed by browser")

                            Button(action: {
                                if meta.canControl {
                                    mediaController.togglePlayPause()
                                }
                            }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isPlaying ? accentTheme.foregroundOnAccent : (meta.canControl ? themeManager.primaryTextColor : themeManager.secondaryTextColor.opacity(0.4)))
                                    .frame(width: 26, height: 26)
                                    .background(
                                        Circle()
                                            .fill(isPlaying ? accentTheme.horizontalGradient : LinearGradient(colors: [Color.white.opacity(meta.canControl ? 0.14 : 0.04)], startPoint: .leading, endPoint: .trailing))
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(isPlaying ? accentTheme.borderGradient : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing), lineWidth: 0.6)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!meta.canControl)
                            .help(meta.canControl ? (isPlaying ? "Pause" : "Play") : "Playback controls managed by browser")

                            Button(action: {
                                if meta.canControl {
                                    mediaController.nextTrack()
                                }
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(meta.canControl ? themeManager.secondaryTextColor : themeManager.secondaryTextColor.opacity(0.25))
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.white.opacity(meta.canControl ? 0.06 : 0.02)))
                            }
                            .buttonStyle(.plain)
                            .disabled(!meta.canControl)
                            .help(meta.canControl ? "Next Track" : "Playback controls managed by browser")
                        }
                    }

                    // Dynamic Gradient Progress Bar
                    if meta.duration > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 2.5)

                                Capsule()
                                    .fill(accentTheme.horizontalGradient)
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(meta.progress))), height: 2.5)
                            }
                        }
                        .frame(height: 2.5)
                    }
                }
            } else {
                // Polished Idle / Ready State
                HStack(alignment: .center, spacing: 10) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 15))
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.45))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Media Playing")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.primaryTextColor.opacity(0.9))

                        Text("Apple Music / Spotify / YouTube ready")
                            .font(.system(size: 9))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.65))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    // Standby Controls
                    HStack(spacing: 6) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 9))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.4))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.04)))

                        Button(action: {
                            mediaController.togglePlayPause()
                        }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .help("Resume Playback")

                        Image(systemName: "forward.fill")
                            .font(.system(size: 9))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.4))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.04)))
                    }
                }
            }
        }
        .padding(.horizontal, IslandSpacing.cardPaddingHorizontal)
        .padding(.vertical, IslandSpacing.cardPaddingVertical)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IslandSpacing.cardCornerRadius)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IslandSpacing.cardCornerRadius)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }
}
