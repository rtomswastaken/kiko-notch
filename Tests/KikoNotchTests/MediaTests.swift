import XCTest
@testable import KikoNotchKit
import CoreAudio
import SwiftUI

final class MediaTests: XCTestCase {
    
    // MARK: - Section 4: MEDIA-001 through MEDIA-008
    
    func testMediaMetadataFormatting() {
        let meta = MediaMetadata(
            title: "Supermassive Black Hole",
            artist: "Muse",
            album: "Black Holes and Revelations",
            duration: 209.0, // 3:29
            elapsedTime: 65.0, // 1:05
            isPlaying: true,
            playerApp: "Music"
        )
        
        XCTAssertEqual(meta.displayTitle, "Supermassive Black Hole")
        XCTAssertEqual(meta.displayArtist, "Muse")
        XCTAssertEqual(meta.elapsedFormatted, "1:05")
        XCTAssertEqual(meta.remainingFormatted, "-2:24")
        XCTAssertEqual(meta.progress, 65.0 / 209.0, accuracy: 0.001)
    }
    
    func testEmptyMediaMetadataFallback() {
        let empty = MediaMetadata.empty
        XCTAssertEqual(empty.displayTitle, "No Media Playing")
        XCTAssertEqual(empty.displayArtist, "Unknown Artist")
        XCTAssertEqual(empty.elapsedFormatted, "0:00")
        XCTAssertEqual(empty.progress, 0.0)
        XCTAssertFalse(empty.isPlaying)
    }
    
    func testProgressClamping() {
        var meta = MediaMetadata(duration: 100.0, elapsedTime: -10.0)
        XCTAssertEqual(meta.progress, 0.0)
        
        meta = MediaMetadata(duration: 100.0, elapsedTime: 150.0)
        XCTAssertEqual(meta.progress, 1.0)
    }
    
    func testAudioOutputDeviceModel() {
        let device = AudioOutputDevice(id: 42, name: "AirPods Pro", uid: "airpods-uid-123", isDefault: true)
        XCTAssertEqual(device.id, 42)
        XCTAssertEqual(device.name, "AirPods Pro")
        XCTAssertEqual(device.uid, "airpods-uid-123")
        XCTAssertTrue(device.isDefault)
    }
    
    func testAudioDeviceManagerRefresh() {
        let manager = AudioDeviceManager.shared
        manager.refreshDevices()
        // Should not crash and should populate or retain valid collection
        XCTAssertNotNil(manager.outputDevices)
    }
    
    func testMediaMetadataAliases() {
        let meta = MediaMetadata(
            title: "Song",
            artist: "Artist",
            album: "Album",
            duration: 120.0,
            elapsedTime: 30.0,
            isPlaying: true,
            playerApp: "Music",
            isShuffle: true,
            isRepeat: true
        )
        XCTAssertEqual(meta.formattedElapsed, "0:30")
        XCTAssertEqual(meta.formattedRemaining, "-1:30")
        XCTAssertTrue(meta.isShuffled)
        XCTAssertTrue(meta.isRepeating)
        XCTAssertNil(meta.artwork)
    }
    
    func testMediaControllerPlaybackControlsNoCrash() {
        let controller = MediaController.shared
        // Ensure none of the public playback triggers crash even when players are not playing
        controller.togglePlayPause()
        controller.nextTrack()
        controller.previousTrack()
        controller.seek(to: 10.0)
        controller.toggleShuffle()
        controller.toggleRepeat()
        controller.refreshMedia()
        XCTAssertNotNil(controller.currentMedia)
    }

    @MainActor
    func testAudioSignalMonitorBaselineAndLevels() {
        let monitor = AudioSignalMonitor.shared
        monitor.stopSampling()

        // Exactly three bars
        XCTAssertEqual(monitor.barLevels.count, 3)

        // Idle baseline is resting baseline (0.15)
        for level in monitor.barLevels {
            XCTAssertEqual(level, 0.15, accuracy: 0.001)
        }
        XCTAssertEqual(monitor.rmsLevel, 0.0, accuracy: 0.001)
        XCTAssertFalse(monitor.isActive)
    }

    @MainActor
    func testAudioSignalMonitorEnergyInjectionAndRMS() {
        let monitor = AudioSignalMonitor.shared
        monitor.injectEnergy(bass: 0.8, mid: 0.6, treble: 0.4)

        XCTAssertEqual(monitor.barLevels.count, 3)
        XCTAssertEqual(monitor.barLevels[0], 0.8, accuracy: 0.01)
        XCTAssertEqual(monitor.barLevels[1], 0.6, accuracy: 0.01)
        XCTAssertEqual(monitor.barLevels[2], 0.4, accuracy: 0.01)

        let expectedRMS = sqrt((0.64 + 0.36 + 0.16) / 3.0)
        XCTAssertEqual(monitor.rmsLevel, Float(expectedRMS), accuracy: 0.01)

        // Clean stop settles back to baseline
        monitor.stopSampling()
        XCTAssertEqual(monitor.barLevels[0], 0.15, accuracy: 0.001)
        XCTAssertEqual(monitor.rmsLevel, 0.0, accuracy: 0.001)
    }

    @MainActor
    func testClosedNotchSizeExpansionWhenPlayingMedia() {
        let idleSize = IslandGeometry.getClosedNotchSize(isPlayingMedia: false)
        let playingSize = IslandGeometry.getClosedNotchSize(isPlayingMedia: true)

        XCTAssertGreaterThan(playingSize.width, idleSize.width)
        XCTAssertEqual(playingSize.width, min(idleSize.width + 96.0, IslandGeometry.maxCollapsedWidth))
        XCTAssertEqual(playingSize.height, idleSize.height)

        // Title banner expansion expands both width and height beneath notch
        let bannerSize = IslandGeometry.getClosedNotchSize(isPlayingMedia: true, isShowingTitleBanner: true)
        XCTAssertGreaterThan(bannerSize.height, playingSize.height)
        XCTAssertEqual(bannerSize.height, idleSize.height + 28.0)
        XCTAssertGreaterThanOrEqual(bannerSize.width, 380.0)
    }

    func testArtworkColorExtractorFallbackAndBoost() {
        let extractor = ArtworkColorExtractor.shared
        // Nil fallback
        let fallback = extractor.extractAccentColor(from: nil as Data?, identifier: "empty-test")
        XCTAssertEqual(fallback, NSColor.white)

        // Synthetic bitmap with vibrant cyan color (R:0, G:200, B:255)
        let size = NSSize(width: 32, height: 32)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor(red: 0.1, green: 0.7, blue: 0.9, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()

        let extracted = extractor.extractAccentColor(from: img, identifier: "cyan-test")
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        extracted.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Brightness and saturation are boosted for dark notch legibility
        XCTAssertGreaterThanOrEqual(b, 0.68)
        XCTAssertGreaterThanOrEqual(s, 0.38)
    }

    func testMultiColorArtworkPaletteExtraction() {
        let extractor = ArtworkColorExtractor.shared

        // Helper to create synthetic split bitmaps
        func createSplitImage(colors: [NSColor]) -> NSImage {
            let img = NSImage(size: NSSize(width: 48, height: 48))
            img.lockFocus()
            let sectionWidth = 48.0 / CGFloat(colors.count)
            for (idx, color) in colors.enumerated() {
                color.setFill()
                NSRect(x: CGFloat(idx) * sectionWidth, y: 0, width: sectionWidth, height: 48).fill()
            }
            img.unlockFocus()
            return img
        }

        // 1. Blue & Purple artwork -> Coordinated 2-color gradient
        let bluePurpleImg = createSplitImage(colors: [
            NSColor(red: 0.05, green: 0.45, blue: 0.95, alpha: 1.0), // Blue
            NSColor(red: 0.65, green: 0.15, blue: 0.85, alpha: 1.0)  // Purple
        ])
        let bpPalette = extractor.extractPalette(from: bluePurpleImg, identifier: "blue-purple-test")
        XCTAssertFalse(bpPalette.isDefaultWhite)
        XCTAssertEqual(bpPalette.colors.count, 3) // Normalized 3 stops for jump-free transitions
        XCTAssertNotNil(bpPalette.primary)
        XCTAssertNotNil(bpPalette.secondary)

        // 2. Orange & Pink artwork -> Coordinated 2-color gradient
        let orangePinkImg = createSplitImage(colors: [
            NSColor(red: 0.95, green: 0.50, blue: 0.05, alpha: 1.0), // Orange
            NSColor(red: 0.95, green: 0.20, blue: 0.55, alpha: 1.0)  // Pink
        ])
        let opPalette = extractor.extractPalette(from: orangePinkImg, identifier: "orange-pink-test")
        XCTAssertFalse(opPalette.isDefaultWhite)
        XCTAssertEqual(opPalette.colors.count, 3)

        // 3. Green & Teal artwork -> Coordinated 2-color gradient
        let greenTealImg = createSplitImage(colors: [
            NSColor(red: 0.10, green: 0.80, blue: 0.20, alpha: 1.0), // Green
            NSColor(red: 0.05, green: 0.75, blue: 0.70, alpha: 1.0)  // Teal
        ])
        let gtPalette = extractor.extractPalette(from: greenTealImg, identifier: "green-teal-test")
        XCTAssertFalse(gtPalette.isDefaultWhite)
        XCTAssertEqual(gtPalette.colors.count, 3)

        // 4. Tri-color artwork (Red, Yellow, Blue) -> 3 distinct colors
        let triImg = createSplitImage(colors: [
            NSColor(red: 0.95, green: 0.10, blue: 0.10, alpha: 1.0), // Red
            NSColor(red: 0.95, green: 0.85, blue: 0.05, alpha: 1.0), // Yellow
            NSColor(red: 0.10, green: 0.40, blue: 0.95, alpha: 1.0)  // Blue
        ])
        let triPalette = extractor.extractPalette(from: triImg, identifier: "tri-color-test")
        XCTAssertFalse(triPalette.isDefaultWhite)
        XCTAssertEqual(triPalette.colors.count, 3)
        XCTAssertNotNil(triPalette.tertiary)

        // 5. Dark artwork (< 0.12 luminance) -> returns default white
        let darkImg = createSplitImage(colors: [
            NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1.0)
        ])
        let darkPalette = extractor.extractPalette(from: darkImg, identifier: "dark-test")
        XCTAssertTrue(darkPalette.isDefaultWhite)
        XCTAssertEqual(darkPalette.primary, Color.white)

        // 6. Light / washed out artwork -> returns default white
        let lightImg = createSplitImage(colors: [
            NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
        ])
        let lightPalette = extractor.extractPalette(from: lightImg, identifier: "light-test")
        XCTAssertTrue(lightPalette.isDefaultWhite)

        // 7. Nil / missing data -> returns default white
        let nilPalette = extractor.extractPalette(from: nil as Data?, identifier: "nil-test")
        XCTAssertTrue(nilPalette.isDefaultWhite)
    }

    @MainActor
    func testAccentThemeManagerTransitionsAndWhiteFallback() {
        let manager = AccentThemeManager.shared

        // Start at clean white
        manager.resetToWhite(animated: false)
        XCTAssertTrue(manager.isDefaultWhite)
        XCTAssertEqual(manager.primaryAccent, Color.white)

        // Switch to media palette
        let mediaPalette = AccentPalette(
            primary: Color.blue,
            secondary: Color.purple,
            tertiary: Color.pink,
            isDefaultWhite: false,
            id: "track-123"
        )
        manager.updatePalette(mediaPalette, animated: false)
        XCTAssertFalse(manager.isDefaultWhite)
        XCTAssertEqual(manager.primaryAccent, Color.blue)
        XCTAssertEqual(manager.secondaryAccent, Color.purple)
        XCTAssertEqual(manager.tertiaryAccent, Color.pink)
        XCTAssertEqual(manager.colors.count, 3)

        // Paused media retains the palette
        XCTAssertFalse(manager.isDefaultWhite)

        // Stopped / session cleared returns to default white
        manager.resetToWhite(animated: false)
        XCTAssertTrue(manager.isDefaultWhite)
        XCTAssertEqual(manager.primaryAccent, Color.white)
    }

    @MainActor
    func testMediaControllerTitleBannerLifecycle() async throws {
        let controller = MediaController.shared
        XCTAssertNotNil(controller.currentAccentColor)

        // Trigger manual banner
        controller.triggerTitleBanner()
        XCTAssertTrue(controller.isShowingTitleBanner)

        // Dismiss immediately
        controller.dismissTitleBanner()
        XCTAssertFalse(controller.isShowingTitleBanner)
    }

    @MainActor
    func testLiveMediaDiscovery() async throws {
        let controller = MediaController.shared
        controller.refreshMedia()
        try await Task.sleep(nanoseconds: 600_000_000)

        let current = controller.currentMedia
        print(">>> LIVE MEDIA DISCOVERY RESULT:")
        print("    Title: '\(current.title)'")
        print("    Artist: '\(current.artist)'")
        print("    Player: '\(current.playerApp)'")
        print("    Playing: \(current.isPlaying)")
        print("    CanControl: \(current.canControl)")
        print("    Artwork Present: \(current.artworkData != nil)")
        print("    Visualizer Bar Levels: \(AudioSignalMonitor.shared.barLevels)")
        print("    Visualizer RMS: \(AudioSignalMonitor.shared.rmsLevel)")

        XCTAssertNotNil(current)
    }
}
