import XCTest
@testable import DockryCore

final class AppleMusicTests: XCTestCase {
    func testReadsMusicsNotification() throws {
        let info: [String: Any] = [
            "Player State": "Playing", "Name": "Clocks", "Artist": "Coldplay", "Album": "A Rush of Blood",
            "PersistentID": NSNumber(value: Int64(bitPattern: 0xA1B2_C3D4_E5F6_0718)),
        ]
        let track = try XCTUnwrap(MusicTrack(playerInfo: info))
        XCTAssertEqual(track, MusicTrack(title: "Clocks", artist: "Coldplay", album: "A Rush of Blood", isPlaying: true, persistentID: "A1B2C3D4E5F60718"))
        XCTAssertNil(MusicTrack(playerInfo: ["Player State": "Stopped", "Name": "Clocks"]))
        XCTAssertFalse(try XCTUnwrap(MusicTrack(playerInfo: ["Player State": "Paused", "Name": "Clocks"])).isPlaying)
    }

    func testReadsTheTrackScriptsOutput() {
        XCTAssertEqual(
            MusicTrack(appleScriptOutput: "paused\nClocks\nColdplay\nA Rush of Blood\nA1B2C3D4E5F60718\n"),
            MusicTrack(title: "Clocks", artist: "Coldplay", album: "A Rush of Blood", isPlaying: false, persistentID: "A1B2C3D4E5F60718"))
        XCTAssertNil(MusicTrack(appleScriptOutput: ""))
    }

    func testReadsPlaybackAndCyclesRepeat() throws {
        let playback = try XCTUnwrap(MusicPlayback(appleScriptOutput: "75\n307\n60\ntrue\nall\n"))
        XCTAssertEqual(playback, MusicPlayback(position: 75, duration: 307, volume: 60, isShuffling: true, repeatMode: .all))
        XCTAssertEqual(playback.repeatMode.next, .one)
        XCTAssertEqual(MusicPlayback.Repeat.one.next, .off)
        XCTAssertNil(MusicPlayback(appleScriptOutput: "75\n307\n60\ntrue\nsometimes\n"))
    }

    func testSearchEscapesTheQueryAndParsesResults() {
        let script = MusicSearchResult.searchScript(#"Say "hi" \ now"#)
        XCTAssertTrue(script.contains(#"for "Say \"hi\" \\ now" only songs"#))
        let results = MusicSearchResult.parseSearch("A1B2C3D4E5F60718\tClocks\tColdplay\tA Rush of Blood\nnot an id\tX\tY\tZ\n")
        XCTAssertEqual(results, [MusicSearchResult(persistentID: "A1B2C3D4E5F60718", title: "Clocks", artist: "Coldplay", album: "A Rush of Blood")])
    }

    func testPlaysOnlyRealPersistentIDs() {
        XCTAssertEqual(
            MusicSearchResult.playScript(persistentID: "A1B2C3D4E5F60718"),
            #"play (first track of library playlist 1 whose persistent ID is "A1B2C3D4E5F60718")"#)
        XCTAssertNil(MusicSearchResult.playScript(persistentID: #"x" & do shell script "rm"#))
    }

    func testMusicIsAWidget() throws {
        XCTAssertEqual(try JSONDecoder().decode(Profile.self, from: Data(#"{"name": "A", "items": ["widget:music"]}"#.utf8)).widgets, [.music])
    }
}
