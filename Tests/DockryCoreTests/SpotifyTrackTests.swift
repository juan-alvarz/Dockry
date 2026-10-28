import XCTest
@testable import DockryCore

final class SpotifyTrackTests: XCTestCase {
    func testReadsAPlayingTrackFromTheNotification() {
        let track = SpotifyTrack(playbackInfo: ["Player State": "Playing", "Name": "Midnight City", "Artist": "M83"])
        XCTAssertEqual(track, SpotifyTrack(title: "Midnight City", artist: "M83", isPlaying: true))
    }

    func testPausedTrackIsNotPlaying() {
        let track = SpotifyTrack(playbackInfo: ["Player State": "Paused", "Name": "Midnight City"])
        XCTAssertEqual(track?.isPlaying, false)
        XCTAssertEqual(track?.artist, "")
    }

    func testStoppedMeansNoTrack() {
        XCTAssertNil(SpotifyTrack(playbackInfo: ["Player State": "Stopped"]))
        XCTAssertNil(SpotifyTrack(playbackInfo: [:]))
    }

    func testReadsTheAppleScriptOutput() {
        let output = "paused\nMidnight City\nM83\nhttps://i.scdn.co/image/abc\n"
        XCTAssertEqual(
            SpotifyTrack(appleScriptOutput: output),
            SpotifyTrack(
                title: "Midnight City", artist: "M83", isPlaying: false,
                artworkURL: URL(string: "https://i.scdn.co/image/abc")))
    }

    func testEmptyAppleScriptOutputMeansNoTrack() {
        XCTAssertNil(SpotifyTrack(appleScriptOutput: "\n"))
        XCTAssertNil(SpotifyTrack(appleScriptOutput: ""))
    }
}
