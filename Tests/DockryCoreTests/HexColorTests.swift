import XCTest
@testable import DockryCore

final class HexColorTests: XCTestCase {
    func testReadsHexColors() throws {
        let (red, green, blue) = try XCTUnwrap(HexColor.components("#FF8000"))
        XCTAssertEqual(red, 1)
        XCTAssertEqual(green, 128.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(blue, 0)
    }

    func testNormalizesCaseAndTheHash() {
        XCTAssertEqual(HexColor.normalized("3563e9"), "#3563E9")
        XCTAssertNil(HexColor.normalized("#12345"))
        XCTAssertNil(HexColor.normalized("#GGGGGG"))
    }

    func testWritesHexColors() {
        XCTAssertEqual(HexColor.string(red: 1, green: 0.5, blue: 0), "#FF8000")
    }

    func testPicksReadableText() {
        XCTAssertTrue(HexColor.prefersLightText("#3563E9"))
        XCTAssertFalse(HexColor.prefersLightText("#FFD166"))
    }

    func testAProfileWithABadColorLoadsWithoutIt() throws {
        let json = #"{ "name": "Gaming", "color": "purple" }"#
        XCTAssertNil(try JSONDecoder().decode(Profile.self, from: Data(json.utf8)).color)
        // Two #s: the color's "# would end a #"…"# string.
        let good = ##"{ "name": "Gaming", "color": "#7c3aed" }"##
        XCTAssertEqual(try JSONDecoder().decode(Profile.self, from: Data(good.utf8)).color, "#7C3AED")
    }
}
