import XCTest
@testable import DockryCore

final class ProfileFileTests: XCTestCase {
    private var directory: URL!
    private var file: ProfileFile!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        file = ProfileFile(url: directory.appendingPathComponent("profiles.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingFileGivesDefaults() {
        let result = file.load()
        XCTAssertEqual(result.library, ProfileLibrary())
        XCTAssertNil(result.error)
    }

    func testSaveThenLoad() throws {
        var library = ProfileLibrary()
        library.activate(named: "Chill")
        library.pin("com.apple.Notes")
        try file.save(library)

        let result = file.load()
        XCTAssertEqual(result.library, library)
        XCTAssertNil(result.error)
    }

    func testTheFilesDateShowsWhenItWasEditedByHand() throws {
        XCTAssertNil(file.modificationDate)
        try file.save(ProfileLibrary())
        let saved = try XCTUnwrap(file.modificationDate)
        try FileManager.default.setAttributes([.modificationDate: saved.addingTimeInterval(5)], ofItemAtPath: file.url.path)
        XCTAssertNotEqual(file.modificationDate, saved)
    }

    func testUnreadableFileGivesDefaultsAndLeavesTheFileAlone() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: file.url)

        let result = file.load()
        XCTAssertEqual(result.library, ProfileLibrary())
        XCTAssertNotNil(result.error)
        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "{ not json")
    }
}
