import Foundation
import AppKit

/// Controls and monitors playback from Apple Music and Spotify via AppleScript & DistributedNotifications.
/// Adapted from Boring Notch for robust, non-blocking media playback and native artwork parsing.
public final class MediaController: ObservableObject, @unchecked Sendable {
    public static let shared = MediaController()
    
    @Published public private(set) var currentMedia: MediaMetadata = .empty
    @Published public var isCollapsed: Bool = true {
        didSet {
            updatePollingRate()
        }
    }
    
    private let queue = DispatchQueue(label: "kiko.media.controller", qos: .userInitiated)
    private var pollTimer: DispatchSourceTimer?
    private var isQuerying = false
    private var lastSpotifyArtworkURL: String?
    private var spotifyArtworkTask: Task<Void, Never>?
    
    private init() {
        setupDistributedNotifications()
        startPolling()
        refreshMedia()
    }
    
    deinit {
        stopPolling()
        spotifyArtworkTask?.cancel()
    }
    
    // MARK: - Distributed Notifications (Instant zero-overhead updates)
    
    private func setupDistributedNotifications() {
        let center = DistributedNotificationCenter.default()
        
        // Apple Music notification
        center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshMedia()
        }
        
        // Spotify notification
        center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshMedia()
        }
    }
    
    // MARK: - Polling Management (Zero-idle CPU)
    
    private func startPolling() {
        stopPolling()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let interval: Double = (currentMedia.isPlaying && !isCollapsed) ? 1.0 : (currentMedia.isPlaying ? 2.5 : 6.0)
        timer.schedule(deadline: .now() + 0.3, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.queryActivePlayers()
        }
        timer.resume()
        self.pollTimer = timer
    }
    
    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }
    
    private func updatePollingRate() {
        startPolling()
    }
    
    public func refreshMedia() {
        queue.async { [weak self] in
            self?.queryActivePlayers()
        }
    }
    
    // MARK: - Player Detection & Query
    
    private func isAppRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    private func queryActivePlayers() {
        guard !isQuerying else { return }
        isQuerying = true
        defer { isQuerying = false }
        
        let spotifyRunning = isAppRunning(bundleId: "com.spotify.client")
        let musicRunning = isAppRunning(bundleId: "com.apple.Music")
        
        // Fast path: if neither media app is running, clear metadata immediately
        if !spotifyRunning && !musicRunning {
            if currentMedia != .empty {
                publishMetadata(.empty)
            }
            return
        }
        
        // 1. Try Spotify if running
        if spotifyRunning {
            if let meta = querySpotify() {
                publishMetadata(meta)
                return
            }
        }
        
        // 2. Try Apple Music if running
        if musicRunning {
            if let meta = queryAppleMusic() {
                publishMetadata(meta)
                return
            }
        }
        
        // If apps are running but not playing anything, report empty state
        if currentMedia != .empty {
            publishMetadata(.empty)
        }
    }
    
    private func publishMetadata(_ meta: MediaMetadata) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stateChanged = (self.currentMedia.isPlaying != meta.isPlaying) || (self.currentMedia.title != meta.title)
            self.currentMedia = meta
            if stateChanged {
                self.updatePollingRate()
            }
        }
    }
    
    // MARK: - Apple Music Integration
    
    private func queryAppleMusic() -> MediaMetadata? {
        let script = """
        tell application "Music"
            try
                set playerState to player state is playing
                set currentTrackName to name of current track
                set currentTrackArtist to artist of current track
                set currentTrackAlbum to album of current track
                set trackPosition to player position
                set trackDuration to duration of current track
                set shuffleState to shuffle enabled
                set repeatState to song repeat
                if repeatState is off then
                    set repeatValue to 1
                else if repeatState is one then
                    set repeatValue to 2
                else if repeatState is all then
                    set repeatValue to 3
                end if

                try
                    set artData to data of artwork 1 of current track
                on error
                    set artData to ""
                end try
                
                set currentVolume to sound volume
                return {playerState, currentTrackName, currentTrackArtist, currentTrackAlbum, trackPosition, trackDuration, shuffleState, repeatValue, currentVolume, artData}
            on error
                return {false, "", "", "", 0, 0, false, 0, 50, ""}
            end try
        end tell
        """
        
        var errorDict: NSDictionary?
        guard let scriptObj = NSAppleScript(source: script) else { return nil }
        let descriptor = scriptObj.executeAndReturnError(&errorDict)
        guard errorDict == nil, descriptor.numberOfItems >= 10 else { return nil }
        
        let isPlaying = descriptor.atIndex(1)?.booleanValue ?? false
        let title = descriptor.atIndex(2)?.stringValue ?? ""
        let artist = descriptor.atIndex(3)?.stringValue ?? ""
        let album = descriptor.atIndex(4)?.stringValue ?? ""
        let elapsed = descriptor.atIndex(5)?.doubleValue ?? 0.0
        let duration = descriptor.atIndex(6)?.doubleValue ?? 0.0
        let isShuffle = descriptor.atIndex(7)?.booleanValue ?? false
        let repeatMode = descriptor.atIndex(8)?.int32Value ?? 0
        let isRepeat = repeatMode > 1
        
        // If track name is blank, Music is idle/empty
        guard !title.isEmpty else { return nil }
        
        let artData = descriptor.atIndex(10)?.data
        let finalArtData: Data? = (artData != nil && !artData!.isEmpty) ? artData : (self.currentMedia.title == title ? self.currentMedia.artworkData : nil)
        
        return MediaMetadata(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlaying,
            playerApp: "Music",
            isShuffle: isShuffle,
            isRepeat: isRepeat,
            artworkData: finalArtData
        )
    }
    
    // MARK: - Spotify Integration
    
    private func querySpotify() -> MediaMetadata? {
        let script = """
        tell application "Spotify"
            try
                set playerState to player state is playing
                set currentTrackName to name of current track
                set currentTrackArtist to artist of current track
                set currentTrackAlbum to album of current track
                set trackPosition to player position
                set trackDuration to (duration of current track) / 1000.0
                set shuffleState to shuffling
                set repeatState to repeating
                set currentVolume to sound volume
                set artUrl to artwork url of current track
                return {playerState, currentTrackName, currentTrackArtist, currentTrackAlbum, trackPosition, trackDuration, shuffleState, repeatState, currentVolume, artUrl}
            on error
                return {false, "", "", "", 0, 0, false, false, 50, ""}
            end try
        end tell
        """
        
        var errorDict: NSDictionary?
        guard let scriptObj = NSAppleScript(source: script) else { return nil }
        let descriptor = scriptObj.executeAndReturnError(&errorDict)
        guard errorDict == nil, descriptor.numberOfItems >= 10 else { return nil }
        
        let isPlaying = descriptor.atIndex(1)?.booleanValue ?? false
        let title = descriptor.atIndex(2)?.stringValue ?? ""
        let artist = descriptor.atIndex(3)?.stringValue ?? ""
        let album = descriptor.atIndex(4)?.stringValue ?? ""
        let elapsed = descriptor.atIndex(5)?.doubleValue ?? 0.0
        let duration = descriptor.atIndex(6)?.doubleValue ?? 0.0
        let isShuffle = descriptor.atIndex(7)?.booleanValue ?? false
        let isRepeat = descriptor.atIndex(8)?.booleanValue ?? false
        let artworkURL = descriptor.atIndex(10)?.stringValue ?? ""
        
        // If track name is blank, Spotify is idle/empty
        guard !title.isEmpty else { return nil }
        
        let artData: Data? = self.currentMedia.title == title ? self.currentMedia.artworkData : nil
        
        // Asynchronously load artwork from URL if changed
        if !artworkURL.isEmpty && artworkURL != lastSpotifyArtworkURL {
            lastSpotifyArtworkURL = artworkURL
            if let url = URL(string: artworkURL) {
                spotifyArtworkTask?.cancel()
                spotifyArtworkTask = Task.detached(priority: .utility) { [weak self] in
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        await MainActor.run { [weak self] in
                            guard let self = self, self.currentMedia.title == title else { return }
                            var updated = self.currentMedia
                            updated.artworkData = data
                            self.currentMedia = updated
                        }
                    }
                }
            }
        }
        
        return MediaMetadata(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlaying,
            playerApp: "Spotify",
            isShuffle: isShuffle,
            isRepeat: isRepeat,
            artworkData: artData
        )
    }
    
    // MARK: - Playback Controls
    
    public func togglePlayPause() {
        let app = targetPlayerApp()
        let script = "tell application \"\(app)\" to playpause"
        executeScriptAndRefresh(script)
    }
    
    public func nextTrack() {
        let app = targetPlayerApp()
        let script = "tell application \"\(app)\" to next track"
        executeScriptAndRefresh(script)
    }
    
    public func previousTrack() {
        let app = targetPlayerApp()
        let script = "tell application \"\(app)\" to previous track"
        executeScriptAndRefresh(script)
    }
    
    public func seek(to seconds: Double) {
        let app = targetPlayerApp()
        let script = "tell application \"\(app)\" to set player position to \(seconds)"
        executeScriptAndRefresh(script)
    }
    
    public func toggleShuffle() {
        let app = targetPlayerApp()
        let script = (app == "Spotify")
            ? "tell application \"Spotify\" to set shuffling to not shuffling"
            : "tell application \"Music\" to set shuffle enabled to not shuffle enabled"
        executeScriptAndRefresh(script)
    }
    
    public func toggleRepeat() {
        let app = targetPlayerApp()
        let script: String
        if app == "Spotify" {
            script = "tell application \"Spotify\" to set repeating to not repeating"
        } else {
            script = """
            tell application "Music"
                if song repeat is off then
                    set song repeat to all
                else
                    set song repeat to off
                end if
            end tell
            """
        }
        executeScriptAndRefresh(script)
    }
    
    private func targetPlayerApp() -> String {
        if currentMedia.playerApp == "Spotify" && isAppRunning(bundleId: "com.spotify.client") {
            return "Spotify"
        }
        if currentMedia.playerApp == "Music" && isAppRunning(bundleId: "com.apple.Music") {
            return "Music"
        }
        if isAppRunning(bundleId: "com.apple.Music") {
            return "Music"
        }
        if isAppRunning(bundleId: "com.spotify.client") {
            return "Spotify"
        }
        return "Music"
    }
    
    private func executeScriptAndRefresh(_ script: String) {
        queue.async { [weak self] in
            var error: NSDictionary?
            if let scriptObj = NSAppleScript(source: script) {
                scriptObj.executeAndReturnError(&error)
            }
            Thread.sleep(forTimeInterval: 0.12)
            self?.queryActivePlayers()
        }
    }
}
