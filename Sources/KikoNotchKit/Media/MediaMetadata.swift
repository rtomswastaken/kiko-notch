import Foundation
import AppKit

/// Metadata describing active or recent media playback
public struct MediaMetadata: Sendable, Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double
    public var elapsedTime: Double
    public var isPlaying: Bool
    public var playerApp: String
    public var isShuffle: Bool
    public var isRepeat: Bool
    
    // We store artwork data or reference safely for sendable equality
    public var artworkData: Data?
    
    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        duration: Double = 0.0,
        elapsedTime: Double = 0.0,
        isPlaying: Bool = false,
        playerApp: String = "None",
        isShuffle: Bool = false,
        isRepeat: Bool = false,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.isPlaying = isPlaying
        self.playerApp = playerApp
        self.isShuffle = isShuffle
        self.isRepeat = isRepeat
        self.artworkData = artworkData
    }
    
    public var artworkImage: NSImage? {
        guard let data = artworkData else { return nil }
        return NSImage(data: data)
    }
    
    public var displayTitle: String {
        title.isEmpty ? "No Media Playing" : title
    }
    
    public var displayArtist: String {
        artist.isEmpty ? "Unknown Artist" : artist
    }
    
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsedTime / duration, 0.0), 1.0)
    }
    
    public static func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let totalSecs = Int(seconds)
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var elapsedFormatted: String {
        Self.formatTime(elapsedTime)
    }
    
    public var remainingFormatted: String {
        let remaining = max(0.0, duration - elapsedTime)
        return "-\(Self.formatTime(remaining))"
    }
    
    public static let empty = MediaMetadata()
}
