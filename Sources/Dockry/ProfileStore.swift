import AppKit
import Combine
import DockryCore

/// The profile library as observable app state; every change is saved to disk.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var library: ProfileLibrary
    /// Set when profiles.json couldn't be read and the defaults are in use instead. Changes
    /// aren't saved meanwhile, so the user's file isn't replaced while they fix it.
    @Published private(set) var loadError: Error?
    /// A profile renamed through `updateProfile`, sent once the library has the new name,
    /// so whatever goes by profile name can follow it.
    let renamed = PassthroughSubject<(from: String, to: String), Never>()

    private let file = ProfileFile()

    init() {
        let result = file.load()
        library = result.library
        loadError = result.error
    }

    var active: Profile { library.active }

    func activate(named name: String) {
        update { $0.activate(named: name) }
    }

    func pin(_ bundleID: String) {
        update { $0.pin(bundleID) }
    }

    func unpin(_ bundleID: String) {
        update { $0.unpin(bundleID) }
    }

    /// Changes the active profile, such as the order of its dock.
    func updateActive(_ change: (inout Profile) -> Void) {
        update { $0.updateActive(change) }
    }

    /// Returns the new profile's name.
    @discardableResult
    func addProfile(freshApps: Bool = false) -> String {
        var name = ""
        update { name = $0.addProfile(named: freshApps ? "Fresh Profile" : "New Profile", freshApps: freshApps) }
        return name
    }

    /// Returns the copy's name.
    @discardableResult
    func duplicateProfile(named name: String) -> String? {
        var copy: String?
        update { copy = $0.duplicateProfile(named: name) }
        return copy
    }

    func removeProfile(named name: String) {
        update { $0.removeProfile(named: name) }
    }

    /// Returns the profile's name afterwards, or nil if there's no such profile.
    @discardableResult
    func updateProfile(named name: String, _ change: (inout Profile) -> Void) -> String? {
        var newName: String?
        update { newName = $0.updateProfile(named: name, change) }
        guard let newName, newName != name else { return newName }
        // A fresh profile's app data goes with its new name.
        if library.profiles.first(where: { $0.name == newName })?.freshApps == true {
            AppInstances.moveData(from: name, to: newName)
        }
        renamed.send((name, newName))
        return newName
    }

    func moveProfile(named name: String, by offset: Int) {
        update { $0.moveProfile(named: name, by: offset) }
    }

    /// Picks up changes made to profiles.json by hand.
    func reload() {
        let result = file.load()
        library = result.library
        loadError = result.error
    }

    /// Opens profiles.json in TextEdit. Not in the default app for JSON files: on a Mac with
    /// Xcode, that's Xcode.
    func openFile() {
        if !file.exists {
            save(library)
        }
        guard let textEdit = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else {
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
            return
        }
        NSWorkspace.shared.open([file.url], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
    }

    func showFileInFinder() {
        if !file.exists {
            save(library)
        }
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    private func update(_ change: (inout ProfileLibrary) -> Void) {
        var updated = library
        change(&updated)
        guard updated != library else { return }
        library = updated
        save(updated)
    }

    private func save(_ library: ProfileLibrary) {
        guard loadError == nil else { return }
        do {
            try file.save(library)
        } catch {
            NSLog("Dockry: couldn't save profiles: \(error)")
        }
    }
}
