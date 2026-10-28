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

    func testUnreadableFileIsBackedUpAndDefaultsAreUsed() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: file.url)

        let result = file.load()
        XCTAssertEqual(result.library, ProfileLibrary())
        XCTAssertNotNil(result.error)
        XCTAssertTrue(file.exists)
        let backup = file.url.appendingPathExtension("broken")
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "{ not json")
    }
}
