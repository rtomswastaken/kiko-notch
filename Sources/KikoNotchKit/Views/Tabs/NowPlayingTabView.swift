import SwiftUI
import AppKit

/// Dedicated Now Playing Media Player Tab View
public struct NowPlayingTabView: View {
    @ObservedObject public var controller = MediaController.shared
    @ObservedObject public var audioManager = AudioDeviceManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0.0
    
    public init() {}
    
    private var meta: MediaMetadata {
        controller.currentMedia
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                if meta.isPlaying || !meta.title.isEmpty {
                    // Active Player Presentation
                    activePlayerView
                } else {
                    // Clean, Useful Empty State
                    emptyMediaState
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
    }
    
    @ViewBuilder
    private var activePlayerView: some View {
        VStack(spacing: 12) {
            // Artwork & Metadata Row
            HStack(spacing: 14) {
                // Large Album Artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                    
                    if let img = meta.artworkImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                
                // Track Info & Visualizer
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(meta.displayTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                        
                        if meta.isPlaying {
                            AudioVisualizerView(
                                isPlaying: true,
                                barCount: 4,
                                barWidth: 2,
                                maxHeight: 11,
                                color: .white
                            )
                        }
                    }
                    
                    Text(meta.displayArtist)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(1)
                    
                    if !meta.album.isEmpty {
                        Text(meta.album)
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: meta.playerApp.lowercased().contains("spotify") ? "waveform" : "applelogo")
                            .font(.system(size: 9))
                        Text(meta.playerApp)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            
            // Progress Scrubber Bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        let progress = meta.duration > 0 ? (isScrubbing ? scrubValue : meta.elapsedTime) / meta.duration : 0.0
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 4)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                isScrubbing = true
                                let fraction = max(0.0, min(1.0, Double(val.location.x / geo.size.width)))
                                scrubValue = fraction * meta.duration
                            }
                            .onEnded { _ in
                                isScrubbing = false
                                controller.seek(to: scrubValue)
                            }
                    )
                }
                .frame(height: 8)
                
                HStack {
                    Text(meta.formattedElapsed)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    Text(meta.formattedRemaining)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .padding(.horizontal, 4)
            
            // Transport Controls Row
            HStack(spacing: 16) {
                // Shuffle
                Button(action: {
                    controller.toggleShuffle()
                }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12))
                        .foregroundColor(meta.isShuffled ? .white : themeManager.secondaryTextColor.opacity(0.6))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Previous
                Button(action: {
                    controller.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                
                // Play / Pause
                Button(action: {
                    controller.togglePlayPause()
                }) {
                    Image(systemName: meta.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                
                // Next
                Button(action: {
                    controller.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Repeat
                Button(action: {
                    controller.toggleRepeat()
                }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 12))
                        .foregroundColor(meta.isRepeating ? .white : themeManager.secondaryTextColor.opacity(0.6))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            
            // Bottom Row: Audio Output Selection & Volume
            HStack(spacing: 10) {
                // Output Device Menu
                Menu {
                    ForEach(audioManager.outputDevices) { device in
                        Button {
                            audioManager.selectDevice(device)
                        } label: {
                            HStack {
                                Text(device.name)
                                if device.isDefault {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                        Text(audioManager.currentOutputDevice?.name ?? "Speakers")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Spacer()
                
                // Volume Slider
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Slider(value: Binding(
                        get: { Double(audioManager.systemVolume) },
                        set: { audioManager.setVolume(Float($0)) }
                    ), in: 0.0...1.0)
                    .frame(width: 90)
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .padding(.top, 2)
        }
    }
    
    @ViewBuilder
    private var emptyMediaState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.6))
            }
            
            VStack(spacing: 3) {
                Text("No Media Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text("Start playing audio in Apple Music or Spotify to control playback from Kiko Notch")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            HStack(spacing: 10) {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "music://")!)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 11))
                        Text("Apple Music")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "spotify://")!)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                        Text("Spotify")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
