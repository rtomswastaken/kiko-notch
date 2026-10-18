import SwiftUI
import AppKit

/// Comprehensive expanded media player widget
public struct MediaWidgetView: View {
    @ObservedObject public var controller = MediaController.shared
    @ObservedObject public var audioManager = AudioDeviceManager.shared
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0.0
    
    public init() {}
    
    private var meta: MediaMetadata {
        controller.currentMedia
    }
    
    public var body: some View {
        if meta.title.isEmpty {
            emptyMediaView
        } else {
            activePlayerView
        }
    }
    
    @ViewBuilder
    private var activePlayerView: some View {
        VStack(spacing: 10) {
            // Top Row: Artwork + Track details + Output Selector
            HStack(spacing: 12) {
                // Album Artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.08))
                    
                    if let img = meta.artworkImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Album artwork")
                
                // Track Info & Visualizer
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(meta.displayTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        if meta.isPlaying {
                            AudioVisualizerView(
                                isPlaying: true,
                                barCount: 4,
                                barWidth: 2,
                                maxHeight: 11,
                                color: .accentColor
                            )
                        }
                    }
                    
                    Text(meta.displayArtist)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if meta.playerApp != "None" {
                        Text(meta.playerApp)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Audio Output Device Picker Menu
                Menu {
                    ForEach(audioManager.outputDevices) { device in
                        Button {
                            audioManager.setDefaultOutputDevice(deviceID: device.id)
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
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Audio output device selector")
                .accessibilityHint("Active device: \(audioManager.defaultOutputDevice?.name ?? "Unknown")")
            }
            
            // Progress Bar & Scrubbing
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 4)
                        
                        // Progress fill
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(
                                width: max(0, min(geo.size.width * CGFloat(isScrubbing ? scrubValue : meta.progress), geo.size.width)),
                                height: 4
                            )
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                isScrubbing = true
                                let clamped = max(0.0, min(1.0, Double(val.location.x / geo.size.width)))
                                scrubValue = clamped
                            }
                            .onEnded { val in
                                let clamped = max(0.0, min(1.0, Double(val.location.x / geo.size.width)))
                                isScrubbing = false
                                if meta.duration > 0 {
                                    controller.seek(to: clamped * meta.duration)
                                }
                            }
                    )
                }
                .frame(height: 8)
                
                // Elapsed & Remaining times
                HStack {
                    Text(meta.elapsedFormatted)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(meta.remainingFormatted)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback progress \(Int(meta.progress * 100)) percent")
            
            // Playback Control Buttons: Shuffle, Prev, Play/Pause, Next, Repeat
            HStack(spacing: 24) {
                // Shuffle Button
                Button {
                    controller.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12))
                        .foregroundColor(meta.isShuffle ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Shuffle \(meta.isShuffle ? "on" : "off")")
                
                // Previous Button
                Button {
                    controller.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous track")
                
                // Play / Pause Button
                Button {
                    controller.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 34, height: 34)
                        
                        Image(systemName: meta.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: meta.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(meta.isPlaying ? "Pause playback" : "Start playback")
                
                // Next Button
                Button {
                    controller.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next track")
                
                // Repeat Button
                Button {
                    controller.toggleRepeat()
                } label: {
                    Image(systemName: "repeat")
                        .font(.system(size: 12))
                        .foregroundColor(meta.isRepeat ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Repeat \(meta.isRepeat ? "on" : "off")")
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
        )
    }
    
    @ViewBuilder
    private var emptyMediaView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("No Media Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Start playing audio in Apple Music or Spotify")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "music://")!)
                }) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Open Apple Music")
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "spotify://")!)
                }) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Open Spotify")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
