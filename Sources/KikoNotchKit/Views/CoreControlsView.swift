//
//  CoreControlsView.swift
//  KikoNotchKit
//
//  Real CoreAudio volume and DisplayServices brightness controls
//  built on the Boring Notch foundation.
//

import SwiftUI
import AppKit

public struct CoreControlsView: View {
    @ObservedObject public var volumeManager = VolumeManager.shared
    @ObservedObject public var brightnessManager = BrightnessManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @ObservedObject public var accentTheme = AccentThemeManager.shared
    
    @State private var isDraggingVolume = false
    @State private var volumeSliderValue: Double = 0.5
    
    @State private var isDraggingBrightness = false
    @State private var brightnessSliderValue: Double = 0.8

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Volume Row
            HStack(spacing: 10) {
                Button(action: {
                    volumeManager.toggleMute()
                }) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(volumeManager.isMuted ? .red : themeManager.primaryTextColor)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(volumeManager.isMuted ? "Unmute Volume" : "Mute Volume")
                .accessibilityLabel(volumeManager.isMuted ? "Unmute Volume" : "Mute Volume")

                Slider(
                    value: Binding(
                        get: { Double(volumeManager.rawVolume) },
                        set: { newVal in
                            volumeManager.setAbsolute(Float32(newVal))
                        }
                    ),
                    in: 0.0...1.0
                )
                .accentColor(accentTheme.primaryAccent)
                .accessibilityLabel("System Volume Slider")

                Text("\(Int(volumeManager.rawVolume * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )

            // Brightness Row
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(brightnessManager.isSupported ? themeManager.primaryTextColor : themeManager.secondaryTextColor.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.08)))

                if brightnessManager.isSupported {
                    Slider(
                        value: Binding(
                            get: { Double(brightnessManager.rawBrightness) },
                            set: { newVal in
                                brightnessManager.setAbsolute(value: Float(newVal))
                            }
                        ),
                        in: 0.0...1.0
                    )
                    .accentColor(accentTheme.primaryAccent)
                    .accessibilityLabel("Display Brightness Slider")

                    Text("\(Int(brightnessManager.rawBrightness * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 36, alignment: .trailing)
                } else {
                    Text("Display brightness controlled externally")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private var volumeIcon: String {
        if volumeManager.isMuted || volumeManager.rawVolume == 0 {
            return "speaker.slash.fill"
        } else if volumeManager.rawVolume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volumeManager.rawVolume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
