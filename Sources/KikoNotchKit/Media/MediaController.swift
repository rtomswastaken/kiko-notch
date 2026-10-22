//
//  MediaController.swift
//  KikoNotchKit
//
//  Universal media controller supporting Apple Music, Spotify, and Browser playback
//  (Arc, Google Chrome, Safari, Brave) with native artwork resolution and non-blocking AppleScript.
//

import Foundation
import AppKit
import SwiftUI

public final class MediaController: ObservableObject, @unchecked Sendable {
    public static let shared = MediaController()

    @Published public private(set) var currentMedia: MediaMetadata = .empty
    @Published public private(set) var currentAccentColor: Color = Color.white
    @Published public private(set) var currentPalette: AccentPalette = .defaultWhite
    @Published public private(set) var isShowingTitleBanner: Bool = false
    @Published public var isCollapsed: Bool = true {
        didSet {
            updatePollingRate()
        }
    }

    private let queue = DispatchQueue(label: "kiko.media.controller", qos: .userInitiated)
    private var pollTimer: DispatchSourceTimer?
    private var isQuerying = false

    // Track banner announcement tracking
    private var lastAnnouncedTrackId: String = ""
    private var titleBannerDismissTask: Task<Void, Never>?

    // Artwork caching and background tasks
    private var lastSpotifyArtworkURL: String?
    private var spotifyArtworkTask: Task<Void, Never>?
    private var lastYouTubeThumbnailURL: String?
    private var youtubeThumbnailTask: Task<Void, Never>?
    private var itunesArtworkTask: Task<Void, Never>?
    private var lastITunesQuery: String?

    // Active browser tracking for controls
    private var activeBrowserApp: String = "Arc"

    private init() {
        setupDistributedNotifications()
        startPolling()
        refreshMedia()
    }

    deinit {
        stopPolling()
        titleBannerDismissTask?.cancel()
        spotifyArtworkTask?.cancel()
        youtubeThumbnailTask?.cancel()
        itunesArtworkTask?.cancel()
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
        let interval: Double = (currentMedia.isPlaying && !isCollapsed) ? 1.0 : (currentMedia.isPlaying ? 2.0 : 5.0)
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

    // MARK: - Player Detection & Multi-Source Query

    private func isAppRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    private func queryActivePlayers() {
        guard !isQuerying else { return }
        isQuerying = true
        defer { isQuerying = false }

        var candidates: [MediaMetadata] = []

        // 1. Query Spotify if running
        if isAppRunning(bundleId: "com.spotify.client") {
            if let spotify = querySpotify() {
                candidates.append(spotify)
            }
        }

        // 2. Query Apple Music if running
        if isAppRunning(bundleId: "com.apple.Music") {
            if let music = queryAppleMusic() {
                candidates.append(music)
            }
        }

        // 3. Query Browser Media (Arc, Chrome, Safari, Brave)
        if let browserMedia = queryBrowserMedia() {
            candidates.append(browserMedia)
        }

        // Prioritize actively playing media first
        if let playingCandidate = candidates.first(where: { $0.isPlaying }) {
            publishMetadata(playingCandidate)
            return
        }

        // If no candidate is playing, retain the most recently paused track
        if let pausedCandidate = candidates.first(where: { !$0.title.isEmpty }) {
            publishMetadata(pausedCandidate)
            return
        }

        // Otherwise report empty
        if currentMedia != .empty {
            publishMetadata(.empty)
        }
    }

    public func publishMetadata(_ meta: MediaMetadata) {
        let palette = ArtworkColorExtractor.shared.extractPalette(
            from: meta.artworkData,
            identifier: "\(meta.playerApp):\(meta.title):\(meta.artist)"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let stateChanged = (self.currentMedia.isPlaying != meta.isPlaying) || (self.currentMedia.title != meta.title)
            self.currentMedia = meta
            self.currentAccentColor = palette.primary
            self.currentPalette = palette

            // Synchronize with global AccentThemeManager
            if meta.isPlaying || !meta.title.isEmpty {
                // Active session (playing or paused): adopt or retain artwork-derived palette
                AccentThemeManager.shared.updatePalette(palette, animated: true)
            } else {
                // Truly stopped / empty session: smoothly return to default white accent
                AccentThemeManager.shared.resetToWhite(animated: true)
            }

            // Activate or pause audio visualizer engine synchronously with playback
            if meta.isPlaying {
                AudioSignalMonitor.shared.resume()
            } else {
                AudioSignalMonitor.shared.pause()
            }

            if stateChanged {
                self.updatePollingRate()

                // Trigger 3.5s title announcement beneath notch when a new track starts playing
                if meta.isPlaying && !meta.title.isEmpty && meta.title != self.lastAnnouncedTrackId {
                    self.lastAnnouncedTrackId = meta.title
                    self.triggerTitleBanner()
                } else if !meta.isPlaying {
                    self.dismissTitleBanner()
                }
            }
        }
    }

    public func triggerTitleBanner() {
        guard !NotchIndicatorManager.shared.isIndicatorVisible else { return }
        titleBannerDismissTask?.cancel()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            self.isShowingTitleBanner = true
        }
        titleBannerDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self?.isShowingTitleBanner = false
                }
            }
        }
    }

    public func dismissTitleBanner() {
        titleBannerDismissTask?.cancel()
        titleBannerDismissTask = nil
        if isShowingTitleBanner {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                self.isShowingTitleBanner = false
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

                set artData to ""
                try
                    if (count of artworks of current track) > 0 then
                        set artData to data of artwork 1 of current track
                    end if
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

        guard !title.isEmpty else { return nil }

        let artData = descriptor.atIndex(10)?.data
        let finalArtData: Data? = (artData != nil && !artData!.isEmpty) ? artData : (self.currentMedia.title == title ? self.currentMedia.artworkData : nil)

        // Asynchronously fetch from iTunes search if artwork is missing
        if finalArtData == nil && !title.isEmpty {
            fetchITunesArtworkIfNeeded(title: title, artist: artist)
        }

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
            canControl: true,
            artworkData: finalArtData
        )
    }

    private func fetchITunesArtworkIfNeeded(title: String, artist: String) {
        let queryKey = "\(artist)-\(title)"
        guard queryKey != lastITunesQuery else { return }
        lastITunesQuery = queryKey

        itunesArtworkTask?.cancel()
        itunesArtworkTask = Task.detached(priority: .utility) { [weak self] in
            let term = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            guard let url = URL(string: "https://itunes.apple.com/search?term=\(term)&entity=song&limit=1") else { return }

            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artUrlStr = (first["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100bb", with: "300x300bb"),
                  let artUrl = URL(string: artUrlStr),
                  let (imageData, _) = try? await URLSession.shared.data(from: artUrl)
            else { return }

            await MainActor.run { [weak self] in
                guard let self = self, self.currentMedia.title == title else { return }
                var updated = self.currentMedia
                updated.artworkData = imageData
                self.currentMedia = updated
                let palette = ArtworkColorExtractor.shared.extractPalette(
                    from: imageData,
                    identifier: "\(updated.playerApp):\(updated.title):\(updated.artist)"
                )
                self.currentAccentColor = palette.primary
                self.currentPalette = palette
                AccentThemeManager.shared.updatePalette(palette, animated: true)
            }
        }
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

        guard !title.isEmpty else { return nil }

        let artData: Data? = self.currentMedia.title == title ? self.currentMedia.artworkData : nil

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
                            let palette = ArtworkColorExtractor.shared.extractPalette(
                                from: data,
                                identifier: "\(updated.playerApp):\(updated.title):\(updated.artist)"
                            )
                            self.currentAccentColor = palette.primary
                            self.currentPalette = palette
                            AccentThemeManager.shared.updatePalette(palette, animated: true)
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
            canControl: true,
            artworkData: artData
        )
    }

    // MARK: - Browser Media Integration (Arc, Chrome, Safari, Brave)

    private func queryBrowserMedia() -> MediaMetadata? {
        let arcRunning = isAppRunning(bundleId: "company.thebrowser.Browser")
        let chromeRunning = isAppRunning(bundleId: "com.google.Chrome")
        let safariRunning = isAppRunning(bundleId: "com.apple.Safari")
        let braveRunning = isAppRunning(bundleId: "com.brave.Browser")

        guard arcRunning || chromeRunning || safariRunning || braveRunning else { return nil }

        // Script checking Arc first, then Chrome, then Safari, then Brave
        let script = """
        tell application "System Events"
            set isArcRunning to (count of (processes whose bundle identifier is "company.thebrowser.Browser")) > 0
            set isChromeRunning to (count of (processes whose bundle identifier is "com.google.Chrome")) > 0
            set isSafariRunning to (count of (processes whose bundle identifier is "com.apple.Safari")) > 0
            set isBraveRunning to (count of (processes whose bundle identifier is "com.brave.Browser")) > 0
        end tell

        if isArcRunning then
            tell application "Arc"
                try
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabUrl to URL of t
                            if tabUrl contains "youtube.com/watch" or tabUrl contains "music.youtube.com" then
                                tell t
                                    set js to "JSON.stringify({title: document.querySelector('yt-formatted-string.title, h1.ytd-watch-metadata yt-formatted-string')?.textContent || document.title, author: document.querySelector('#channel-name yt-formatted-string a, yt-formatted-string.byline')?.textContent || 'YouTube', playing: !document.querySelector('video, audio')?.paused, currentTime: document.querySelector('video, audio')?.currentTime || 0, duration: document.querySelector('video, audio')?.duration || 0})"
                                    set res to (execute javascript js)
                                    return {res, tabUrl, "Arc"}
                                end tell
                            end if
                        end repeat
                    end repeat
                end try
            end tell
        end if

        if isChromeRunning then
            tell application "Google Chrome"
                try
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabUrl to URL of t
                            if tabUrl contains "youtube.com/watch" or tabUrl contains "music.youtube.com" then
                                tell t
                                    set js to "JSON.stringify({title: document.querySelector('yt-formatted-string.title, h1.ytd-watch-metadata yt-formatted-string')?.textContent || document.title, author: document.querySelector('#channel-name yt-formatted-string a, yt-formatted-string.byline')?.textContent || 'YouTube', playing: !document.querySelector('video, audio')?.paused, currentTime: document.querySelector('video, audio')?.currentTime || 0, duration: document.querySelector('video, audio')?.duration || 0})"
                                    set res to (execute javascript js)
                                    return {res, tabUrl, "Chrome"}
                                end tell
                            end if
                        end repeat
                    end repeat
                end try
            end tell
        end if

        if isBraveRunning then
            tell application "Brave Browser"
                try
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabUrl to URL of t
                            if tabUrl contains "youtube.com/watch" or tabUrl contains "music.youtube.com" then
                                tell t
                                    set js to "JSON.stringify({title: document.querySelector('yt-formatted-string.title, h1.ytd-watch-metadata yt-formatted-string')?.textContent || document.title, author: document.querySelector('#channel-name yt-formatted-string a, yt-formatted-string.byline')?.textContent || 'YouTube', playing: !document.querySelector('video, audio')?.paused, currentTime: document.querySelector('video, audio')?.currentTime || 0, duration: document.querySelector('video, audio')?.duration || 0})"
                                    set res to (execute javascript js)
                                    return {res, tabUrl, "Brave"}
                                end tell
                            end if
                        end repeat
                    end repeat
                end try
            end tell
        end if

        if isSafariRunning then
            tell application "Safari"
                try
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabUrl to URL of t
                            if tabUrl contains "youtube.com/watch" or tabUrl contains "music.youtube.com" then
                                return {name of t, tabUrl, "Safari"}
                            end if
                        end repeat
                    end repeat
                end try
            end tell
        end if

        return {"", "", ""}
        """

        var errorDict: NSDictionary?
        guard let scriptObj = NSAppleScript(source: script) else { return nil }
        let descriptor = scriptObj.executeAndReturnError(&errorDict)
        guard errorDict == nil, descriptor.numberOfItems >= 3 else { return nil }

        let payload = descriptor.atIndex(1)?.stringValue ?? ""
        let tabUrl = descriptor.atIndex(2)?.stringValue ?? ""
        let browserName = descriptor.atIndex(3)?.stringValue ?? "Arc"

        guard !payload.isEmpty, !tabUrl.isEmpty else { return nil }

        self.activeBrowserApp = browserName

        var trackTitle = "YouTube Video"
        var artistName = "YouTube"
        var isPlaying = true
        var currentTime = 0.0
        var duration = 0.0

        // Parse JSON payload if available (Arc/Chrome/Brave)
        var cleanPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPayload.hasPrefix("\"") && cleanPayload.hasSuffix("\"") && cleanPayload.count >= 2 {
            cleanPayload = String(cleanPayload.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }

        if cleanPayload.starts(with: "{"),
           let data = cleanPayload.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            trackTitle = json["title"] as? String ?? trackTitle
            artistName = json["author"] as? String ?? artistName
            isPlaying = json["playing"] as? Bool ?? true
            currentTime = json["currentTime"] as? Double ?? 0.0
            duration = json["duration"] as? Double ?? 0.0
        } else {
            // Safari fallback raw title parsing
            trackTitle = payload
        }

        // Clean YouTube titles
        if trackTitle.hasSuffix(" - YouTube") {
            trackTitle = String(trackTitle.dropLast(" - YouTube".count))
        }
        if let match = trackTitle.range(of: #"^\([0-9]+\)\s*"#, options: .regularExpression) {
            trackTitle.removeSubrange(match)
        }
        if artistName == "YouTube" && trackTitle.contains(" - ") {
            let parts = trackTitle.components(separatedBy: " - ")
            if parts.count >= 2 {
                artistName = parts[0].trimmingCharacters(in: .whitespaces)
                trackTitle = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            }
        }

        let isYTM = tabUrl.contains("music.youtube.com")
        let appName = isYTM ? "YouTube Music" : "YouTube"
        let albumName = isYTM ? "YouTube Music" : "YouTube"

        // Extract thumbnail URL
        var thumbnailURL: String? = nil
        if let components = URLComponents(string: tabUrl),
           let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !videoId.isEmpty {
            thumbnailURL = "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
        }

        let artData: Data? = self.currentMedia.title == trackTitle ? self.currentMedia.artworkData : nil

        let expectedTitle = trackTitle
        if let thumb = thumbnailURL, thumb != lastYouTubeThumbnailURL, let url = URL(string: thumb) {
            lastYouTubeThumbnailURL = thumb
            youtubeThumbnailTask?.cancel()
            youtubeThumbnailTask = Task.detached(priority: .utility) { [weak self] in
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    await MainActor.run { [weak self] in
                        guard let self = self, self.currentMedia.title == expectedTitle else { return }
                        var updated = self.currentMedia
                        updated.artworkData = data
                        self.currentMedia = updated
                        let palette = ArtworkColorExtractor.shared.extractPalette(
                            from: data,
                            identifier: "\(updated.playerApp):\(updated.title):\(updated.artist)"
                        )
                        self.currentAccentColor = palette.primary
                        self.currentPalette = palette
                        AccentThemeManager.shared.updatePalette(palette, animated: true)
                    }
                }
            }
        } else if artData == nil && !trackTitle.isEmpty && trackTitle != "YouTube Video" {
            fetchITunesArtworkIfNeeded(title: trackTitle, artist: artistName)
        }

        return MediaMetadata(
            title: trackTitle,
            artist: artistName,
            album: albumName,
            duration: duration,
            elapsedTime: currentTime,
            isPlaying: isPlaying,
            playerApp: appName,
            isShuffle: false,
            isRepeat: false,
            canControl: true,
            artworkData: artData
        )
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        if currentMedia.playerApp == "YouTube" || currentMedia.playerApp == "YouTube Music" {
            executeBrowserCommand("(() => { const v = document.querySelector('video, audio'); if (v) { v.paused ? v.play() : v.pause(); } else { const btn = document.querySelector('#play-pause-button'); if (btn) btn.click(); } })()")
            return
        }
        let app = targetPlayerApp()
        let script = "tell application \"\(app)\" to playpause"
        executeScriptAndRefresh(script)
    }

    public func nextTrack() {
        if currentMedia.playerApp == "YouTube" || currentMedia.playerApp == "YouTube Music" {
            executeBrowserCommand("(() => { const btn = document.querySelector('.ytp-next-button, .next-button'); if (btn) btn.click(); })()")
            return
        }
        let app = targetPlayerApp()
        let script = "tell application \"\(app)\" to next track"
        executeScriptAndRefresh(script)
    }

    public func previousTrack() {
        if currentMedia.playerApp == "YouTube" || currentMedia.playerApp == "YouTube Music" {
            executeBrowserCommand("(() => { const btn = document.querySelector('.ytp-prev-button, .previous-button'); if (btn) btn.click(); else history.back(); })()")
            return
        }
        let app = targetPlayerApp()
        let script = "tell application \"\(app)\" to previous track"
        executeScriptAndRefresh(script)
    }

    public func seek(to seconds: Double) {
        if currentMedia.playerApp == "YouTube" || currentMedia.playerApp == "YouTube Music" {
            executeBrowserCommand("(() => { const v = document.querySelector('video, audio'); if (v) v.currentTime = \(seconds); })()")
            return
        }
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

    private func executeBrowserCommand(_ jsCommand: String) {
        let appName = activeBrowserApp
        let script = """
        tell application "\(appName)"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabUrl to URL of t
                        if tabUrl contains "youtube.com/watch" or tabUrl contains "music.youtube.com" then
                            tell t to execute javascript "\(jsCommand)"
                            return
                        end if
                    end repeat
                end repeat
            end try
        end tell
        """
        executeScriptAndRefresh(script)
    }

    private func executeScriptAndRefresh(_ script: String) {
        queue.async { [weak self] in
            var error: NSDictionary?
            if let scriptObj = NSAppleScript(source: script) {
                scriptObj.executeAndReturnError(&error)
            }
            Thread.sleep(forTimeInterval: 0.15)
            self?.queryActivePlayers()
        }
    }
}
