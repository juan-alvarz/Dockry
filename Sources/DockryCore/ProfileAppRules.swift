import Foundation

/// The rules for which profile an app's windows are in and what happens as an app comes
/// forward or is opened. Pure, so every case the user has run into is a unit test
/// (ProfileAppRulesTests); the app's ProfileApps gathers the facts and applies the answers.
///
/// Each window is in the profile that was active when it opened (ProfileWindowRecords).
/// Profiles with fresh apps always keep theirs apart, whatever the setting: their own
/// copies never show in another profile, nor others' in them.
public struct ProfileAppRules: Equatable, Sendable {
    /// "Give each profile its own windows".
    public var isEnabled: Bool
    public var freshProfiles: Set<String>

    public init(isEnabled: Bool, freshProfiles: Set<String> = []) {
        self.isEnabled = isEnabled
        self.freshProfiles = freshProfiles
    }

    public func isFresh(_ profile: String) -> Bool {
        freshProfiles.contains(profile)
    }

    /// Whether the dock shows the app in `active`. `owner` is the profile it opened in (nil
    /// for apps in every profile, like Finder); `windowProfiles` the profiles its windows are
    /// in. An app with no windows goes by the profile it opened in.
    public func isShown(owner: String?, windowProfiles: Set<String>, active: String) -> Bool {
        guard let owner else { return true }
        if isFresh(owner) || isFresh(active) { return owner == active }
        guard isEnabled else { return true }
        return windowProfiles.isEmpty ? owner == active : windowProfiles.contains(active)
    }

    /// The profiles the app is in, for showing which profile plays sound.
    public func profiles(owner: String?, windowProfiles: Set<String>) -> Set<String> {
        guard let owner else { return [] }
        if isEnabled && !isFresh(owner) && !windowProfiles.isEmpty { return windowProfiles }
        return [owner]
    }

    /// The profile a window that just opened goes to: the active one, unless a fresh
    /// profile is involved, whose copies' windows are always its own.
    ///
    /// One that opens off screen, from an app with no window here, wasn't opened by the user:
    /// it's a parked window's own (a browser tab's popup, say) and goes with that window.
    /// `asked` is Dockry having just pressed the app's New Window, which opens here wherever
    /// the app puts it.
    public func newWindowProfile(
        owner: String, active: String, asked: Bool, opensOffScreen: Bool, windowProfiles: Set<String>, focusedProfile: String?
    ) -> String {
        if isFresh(owner) || isFresh(active) { return owner }
        guard isEnabled, !asked, opensOffScreen, !windowProfiles.contains(active) else { return active }
        return focusedProfile ?? (windowProfiles.count == 1 ? windowProfiles.first! : active)
    }

    public enum SwitchFocus: Equatable, Sendable {
        case keep
        /// The front app's window in the new profile comes forward, over its parked one.
        case raiseHere
        /// The keyboard goes to the new profile's front app.
        case handOff
    }

    /// Where the keyboard goes after switching to `active`, from the app in front. Its
    /// window in front may have just been parked, and the keyboard must not stay with it.
    public func focusAfterSwitch(owner: String?, windowProfiles: Set<String>, focusedProfile: String?, active: String) -> SwitchFocus {
        guard let owner, !windowProfiles.isEmpty else { return .keep }
        if !isShown(owner: owner, windowProfiles: windowProfiles, active: active) { return .handOff }
        guard windowProfiles.contains(active), let focusedProfile, focusedProfile != active,
              isEnabled || isFresh(focusedProfile) || isFresh(active)
        else { return .keep }
        return .raiseHere
    }

    public enum Activation: Equatable, Sendable {
        case nothing
        case switchTo(String)
        /// One of its windows in the active profile comes forward, over another profile's.
        case raiseHere
        /// It gets a new window in the active profile (its New Window, ⌘N). An app that
        /// can't open one has its front window brought here instead.
        case openWindowHere
    }

    /// What follows an app coming forward, however it came (Dockry's dock, ⌘Tab, Raycast, a
    /// link, a click). `focusedProfile` is the profile of its window in front, if known.
    /// The same answer for every way in, so nothing depends on telling them apart.
    public func activated(owner: String?, windowProfiles: Set<String>, focusedProfile: String?, active: String) -> Activation {
        guard let owner else { return .nothing }
        if owner != active && (isFresh(owner) || isFresh(active)) { return .switchTo(owner) }
        guard isEnabled, !windowProfiles.isEmpty else { return .nothing }
        if windowProfiles.contains(active) {
            return focusedProfile == active ? .nothing : .raiseHere
        }
        return .openWindowHere
    }

    public enum Opening<App: Equatable>: Equatable {
        /// Launches the app, or brings it forward and reopens a window, as the macOS Dock does.
        case launch
        /// Opens another copy: a fresh profile's, with its own data, or with nil, one with
        /// the usual data.
        case newInstance(profile: String?)
        /// Opens a window of it in the active profile.
        case newWindow(App)
        /// Brings forward this copy, among several of the app.
        case instance(App)
    }

    /// What clicking the app in the dock does in `active`. `here` is its copy shown in the
    /// active profile, `instances` every running copy.
    public func opening<App: Equatable>(here: App?, instances: [App], isFreshCopy: (App) -> Bool, active: String) -> Opening<App> {
        if let here {
            // Opening by URL could bring forward another profile's copy.
            return instances.count > 1 ? .instance(here) : .launch
        }
        if isFresh(active) { return .newInstance(profile: active) }
        guard let other = instances.first(where: { !isFreshCopy($0) }) else {
            // Only fresh profiles' copies are running: a copy with the usual data.
            return instances.isEmpty ? .launch : .newInstance(profile: nil)
        }
        return isEnabled ? .newWindow(other) : .launch
    }
}
