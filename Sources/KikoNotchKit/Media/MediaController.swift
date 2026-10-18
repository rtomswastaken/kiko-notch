import Foundation
import AppKit

/// Controls and monitors playback from Apple Music and Spotify via AppleScript & DistributedNotifications
public final class MediaController: ObservableObject, @unchecked Sendable {
    public static let shared = MediaController()
    
    @Published public private(set) var currentMedia: MediaMetadata = .empty
    @Published public var isCollapsed: Bool = true {
        didSet {
            updatePollingRate()
        }
    }
    
    private let queue = DispatchQueue(label: "kiko.media.controller", qos: .utility)
    private var pollTimer: DispatchSourceTimer?
    private var isQuerying = false
    
    private init() {
        setupDistributedNotifications()
        startPolling()
    }
    
    deinit {
        stopPolling()
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
        let interval: Double = (currentMedia.isPlaying && !isCollapsed) ? 1.0 : (currentMedia.isPlaying ? 3.0 : 8.0)
        timer.schedule(deadline: .now() + 0.5, repeating: interval)
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
    
    // MARK: - AppleScript Execution & Query
    
    private func queryActivePlayers() {
        guard !isQuerying else { return }
        isQuerying = true
        defer { isQuerying = false }
        
        // 1. Try Spotify first if running
        if isAppRunning(bundleId: "com.spotify.client") {
            if let meta = querySpotify() {
                publishMetadata(meta)
                return
            }
        }
        
        // 2. Try Apple Music
        if isAppRunning(bundleId: "com.apple.Music") {
            if let meta = queryAppleMusic() {
                publishMetadata(meta)
                return
            }
        }
        
        // No media playing
        if currentMedia != .empty {
            publishMetadata(.empty)
        }
    }
    
    private func isAppRunning(bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    private func publishMetadata(_ meta: MediaMetadata) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stateChanged = self.currentMedia.isPlaying != meta.isPlaying
            self.currentMedia = meta
            if stateChanged {
                self.updatePollingRate()
            }
        }
    }
    
    // MARK: - Spotify AppleScript
    
    private func querySpotify() -> MediaMetadata? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                set pState to player state as string
                if pState is not "stopped" then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set trackDuration to (duration of current track) / 1000.0
                    set pos to player position
                    set isShuff to shuffling
                    set isRep to repeating
                    set artUrl to artwork url of current track
                    return pState & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & pos & "|||" & isShuff & "|||" & isRep & "|||" & artUrl
                end if
            end tell
        end if
        return "none"
        """
        
        guard let output = executeAppleScript(script), output != "none" else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 8 else { return nil }
        
        let isPlaying = parts[0].lowercased() == "playing"
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4]) ?? 0.0
        let elapsed = Double(parts[5]) ?? 0.0
        let isShuffle = parts[6].lowercased() == "true"
        let isRepeat = parts[7].lowercased() == "true"
        
        var artData: Data? = currentMedia.artworkData
        if parts.count >= 9 && !parts[8].isEmpty {
            let artUrlStr = parts[8].trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: artUrlStr), (title != currentMedia.title || artData == nil) {
                artData = try? Data(contentsOf: url)
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
    
    // MARK: - Apple Music AppleScript
    
    private func queryAppleMusic() -> MediaMetadata? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                set pState to player state as string
                if pState is not "stopped" then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set trackDuration to duration of current track
                    set pos to player position
                    set isShuff to shuffle enabled
                    set isRep to song repeat
                    return pState & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & pos & "|||" & isShuff & "|||" & isRep
                end if
            end tell
        end if
        return "none"
        """
        
        guard let output = executeAppleScript(script), output != "none" else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 8 else { return nil }
        
        let isPlaying = parts[0].lowercased() == "playing"
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4]) ?? 0.0
        let elapsed = Double(parts[5]) ?? 0.0
        let isShuffle = parts[6].lowercased() == "true"
        let isRepeat = parts[7].lowercased() != "off"
        
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
            artworkData: currentMedia.title == title ? currentMedia.artworkData : nil
        )
    }
    
    private func executeAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
    
    // MARK: - Playback Controls
    
    public func togglePlayPause() {
        let app = currentMedia.playerApp == "Spotify" ? "Spotify" : "Music"
        let script = "tell application \"\(app)\" to playpause"
        queue.async { [weak self] in
            _ = self?.executeAppleScript(script)
            self?.refreshMedia()
        }
    }
    
    public func nextTrack() {
        let app = currentMedia.playerApp == "Spotify" ? "Spotify" : "Music"
        let script = "tell application \"\(app)\" to next track"
        queue.async { [weak self] in
            _ = self?.executeAppleScript(script)
            self?.refreshMedia()
        }
    }
    
    public func previousTrack() {
        let app = currentMedia.playerApp == "Spotify" ? "Spotify" : "Music"
        let script = "tell application \"\(app)\" to previous track"
        queue.async { [weak self] in
            _ = self?.executeAppleScript(script)
            self?.refreshMedia()
        }
    }
    
    public func seek(to seconds: Double) {
        let app = currentMedia.playerApp == "Spotify" ? "Spotify" : "Music"
        let script = "tell application \"\(app)\" to set player position to \(seconds)"
        queue.async { [weak self] in
            _ = self?.executeAppleScript(script)
            self?.refreshMedia()
        }
    }
    
    public func toggleShuffle() {
        let app = currentMedia.playerApp == "Spotify" ? "Spotify" : "Music"
        let script = app == "Spotify"
            ? "tell application \"Spotify\" to set shuffling to not shuffling"
            : "tell application \"Music\" to set shuffle enabled to not shuffle enabled"
        queue.async { [weak self] in
            _ = self?.executeAppleScript(script)
            self?.refreshMedia()
        }
    }
    
    public func toggleRepeat() {
        let app = currentMedia.playerApp == "Spotify" ? "Spotify" : "Music"
        let script = app == "Spotify"
            ? "tell application \"Spotify\" to set repeating to not repeating"
            : """
              tell application \"Music\"
                  if song repeat is off then
                      set song repeat to all
                  else
                      set song repeat to off
                  end if
              end tell
              """
        queue.async { [weak self] in
            _ = self?.executeAppleScript(script)
            self?.refreshMedia()
        }
    }
}
