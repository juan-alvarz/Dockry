import XCTest
@testable import DockryCore

/// Each test is a case the user ran into, named for what they expect. Projects is active.
final class ProfileAppRulesTests: XCTestCase {
    private let rules = ProfileAppRules(isEnabled: true)
    private let off = ProfileAppRules(isEnabled: false)
    private let fresh = ProfileAppRules(isEnabled: true, freshProfiles: ["Fresh"])

    private func activated(_ rules: ProfileAppRules, owner: String? = "Chill", windows: Set<String>, focused: String?, active: String = "Projects") -> ProfileAppRules.Activation {
        rules.activated(owner: owner, windowProfiles: windows, focusedProfile: focused, active: active)
    }

    // MARK: Coming forward: the same for the dock, Raycast, ⌘Tab and links

    func testOpeningZenFromRaycastWhileItsOnlyInChillOpensANewWindowInProjects() {
        XCTAssertEqual(activated(rules, windows: ["Chill"], focused: "Chill"), .openWindowHere)
    }

    func testCommandTabToZenWhileItsOnlyInChillAlsoOpensANewWindowHere() {
        XCTAssertEqual(activated(rules, windows: ["Chill"], focused: nil), .openWindowHere)
    }

    func testZenWithAWindowInBothBringsForwardTheOneHereNotTheParkedOne() {
        XCTAssertEqual(activated(rules, windows: ["Chill", "Projects"], focused: "Chill"), .raiseHere)
    }

    func testZenAlreadyShowingItsWindowHereStaysAsItIs() {
        XCTAssertEqual(activated(rules, windows: ["Chill", "Projects"], focused: "Projects"), .nothing)
    }

    func testAnAppWithNoWindowsComingForwardDoesNothing() {
        XCTAssertEqual(activated(rules, windows: [], focused: nil), .nothing)
    }

    func testFinderIsInEveryProfileAndNeverMoves() {
        XCTAssertEqual(activated(rules, owner: nil, windows: ["Chill"], focused: "Chill"), .nothing)
        XCTAssertTrue(rules.isShown(owner: nil, windowProfiles: ["Chill"], active: "Projects"))
        XCTAssertEqual(rules.profiles(owner: nil, windowProfiles: ["Chill"]), [])
    }

    func testWithTheSettingOffNothingMoves() {
        XCTAssertEqual(activated(off, windows: ["Chill"], focused: "Chill"), .nothing)
        XCTAssertTrue(off.isShown(owner: "Chill", windowProfiles: ["Chill"], active: "Projects"))
        XCTAssertEqual(off.opening(here: nil, instances: ["zen"], isFreshCopy: { _ in false }, active: "Projects"), .launch)
    }

    // MARK: The dock

    func testProjectsDockDoesNotShowAnAppWhoseWindowsAreAllInChill() {
        XCTAssertFalse(rules.isShown(owner: "Projects", windowProfiles: ["Chill"], active: "Projects"))
        XCTAssertTrue(rules.isShown(owner: "Projects", windowProfiles: ["Chill"], active: "Chill"))
    }

    func testZenWithWindowsInBothShowsInBoth() {
        XCTAssertTrue(rules.isShown(owner: "Chill", windowProfiles: ["Chill", "Projects"], active: "Projects"))
        XCTAssertTrue(rules.isShown(owner: "Chill", windowProfiles: ["Chill", "Projects"], active: "Chill"))
    }

    func testAnAppWithNoWindowsShowsInTheProfileItOpenedIn() {
        XCTAssertTrue(rules.isShown(owner: "Chill", windowProfiles: [], active: "Chill"))
        XCTAssertFalse(rules.isShown(owner: "Chill", windowProfiles: [], active: "Projects"))
    }

    func testClickingZenInProjectsWhileItsOnlyInChillOpensANewWindowHere() {
        XCTAssertEqual(rules.opening(here: nil, instances: ["zen"], isFreshCopy: { _ in false }, active: "Projects"), .newWindow("zen"))
    }

    func testClickingAnAppWithAWindowHereBringsItForward() {
        XCTAssertEqual(rules.opening(here: "zen", instances: ["zen"], isFreshCopy: { _ in false }, active: "Projects"), .launch)
    }

    private func newWindow(
        _ rules: ProfileAppRules, owner: String = "Chill", active: String = "Projects", asked: Bool = false, offScreen: Bool = false,
        windows: Set<String> = ["Chill"], focused: String? = "Chill"
    ) -> String {
        rules.newWindowProfile(
            owner: owner, active: active, asked: asked, opensOffScreen: offScreen, windowProfiles: windows, focusedProfile: focused)
    }

    func testANewWindowGoesToTheActiveProfile() {
        XCTAssertEqual(newWindow(rules), "Projects")
    }

    func testAPopupOfAParkedWindowGoesWithThatWindow() {
        XCTAssertEqual(newWindow(rules, offScreen: true), "Chill")
        XCTAssertEqual(newWindow(rules, offScreen: true, focused: nil), "Chill")
    }

    func testTheWindowDockryAskedForIsHereEvenIfTheAppOpensItOffScreen() {
        XCTAssertEqual(newWindow(rules, asked: true, offScreen: true), "Projects")
    }

    func testAWindowOpeningOffScreenFromAnAppWithAWindowHereStaysHere() {
        XCTAssertEqual(newWindow(rules, offScreen: true, windows: ["Chill", "Projects"]), "Projects")
        XCTAssertEqual(newWindow(off, offScreen: true), "Projects")
    }

    // MARK: The keyboard after switching

    private func focus(_ rules: ProfileAppRules, owner: String? = "Chill", windows: Set<String>, focused: String?) -> ProfileAppRules.SwitchFocus {
        rules.focusAfterSwitch(owner: owner, windowProfiles: windows, focusedProfile: focused, active: "Projects")
    }

    func testSwitchingAwayFromAnAppWithNoWindowHereGivesTheKeyboardToThisProfilesApp() {
        XCTAssertEqual(focus(rules, windows: ["Chill"], focused: "Chill"), .handOff)
    }

    func testSwitchingWithZenInBothBringsForwardItsWindowHereNotTheOneJustParked() {
        XCTAssertEqual(focus(rules, windows: ["Chill", "Projects"], focused: "Chill"), .raiseHere)
    }

    func testSwitchingLeavesTheKeyboardWhereItIsWhenThatWindowIsHere() {
        XCTAssertEqual(focus(rules, windows: ["Chill", "Projects"], focused: "Projects"), .keep)
        XCTAssertEqual(focus(rules, owner: nil, windows: ["Chill"], focused: "Chill"), .keep)
        XCTAssertEqual(focus(rules, windows: [], focused: nil), .keep)
        XCTAssertEqual(focus(off, windows: ["Chill", "Projects"], focused: "Chill"), .keep)
    }

    // MARK: Sound

    func testSoundIsShownOnTheProfileWithTheAppsWindowsNotTheOneItOpenedIn() {
        XCTAssertEqual(rules.profiles(owner: "Projects", windowProfiles: ["Chill"]), ["Chill"])
        XCTAssertEqual(rules.profiles(owner: "Chill", windowProfiles: []), ["Chill"])
    }

    // MARK: Fresh profiles, whatever the setting

    func testAFreshProfileShowsNoneOfTheOtherProfilesApps() {
        for rules in [fresh, ProfileAppRules(isEnabled: false, freshProfiles: ["Fresh"])] {
            XCTAssertFalse(rules.isShown(owner: "Chill", windowProfiles: ["Fresh"], active: "Fresh"))
            XCTAssertFalse(rules.isShown(owner: "Fresh", windowProfiles: [], active: "Chill"))
            XCTAssertTrue(rules.isShown(owner: "Fresh", windowProfiles: [], active: "Fresh"))
        }
    }

    func testBringingForwardAFreshProfilesCopySwitchesToIt() {
        XCTAssertEqual(activated(fresh, owner: "Fresh", windows: ["Fresh"], focused: "Fresh", active: "Chill"), .switchTo("Fresh"))
        XCTAssertEqual(activated(fresh, owner: "Chill", windows: ["Chill"], focused: "Chill", active: "Fresh"), .switchTo("Chill"))
    }

    func testClickingAnAppInAFreshProfileOpensItsOwnCopy() {
        XCTAssertEqual(fresh.opening(here: nil, instances: ["zen"], isFreshCopy: { _ in false }, active: "Fresh"), .newInstance(profile: "Fresh"))
    }

    func testWithOnlyAFreshProfilesCopyRunningAnotherProfileOpensOneWithTheUsualData() {
        XCTAssertEqual(fresh.opening(here: nil, instances: ["fresh zen"], isFreshCopy: { _ in true }, active: "Chill"), .newInstance(profile: nil))
    }

    func testWithSeveralCopiesClickingBringsForwardThisProfilesOne() {
        let opening = fresh.opening(here: "zen", instances: ["fresh zen", "zen"], isFreshCopy: { $0 == "fresh zen" }, active: "Chill")
        XCTAssertEqual(opening, .instance("zen"))
    }

    func testAFreshProfilesWindowsStayItsOwn() {
        XCTAssertEqual(newWindow(fresh, owner: "Fresh", active: "Chill", windows: ["Fresh"], focused: "Fresh"), "Fresh")
        XCTAssertEqual(fresh.profiles(owner: "Fresh", windowProfiles: ["Chill"]), ["Fresh"])
    }
}
