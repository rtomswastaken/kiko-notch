import XCTest
@testable import KikoNotchKit
import CoreAudio

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
}
