import AppKit
import DockryCore

/// The profile library as observable app state; every change is saved to disk.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var library: ProfileLibrary
    /// Set when profiles.json couldn't be read and the defaults are in use instead. Changes
    /// aren't saved meanwhile, so the user's file isn't replaced while they fix it.
    @Published private(set) var loadError: Error?

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

    func setOpensAppsOnSwitch(_ opensApps: Bool) {
        update { $0.setOpensAppsOnSwitch(opensApps) }
    }

    func reorderPins(_ order: [String]) {
        update { $0.reorderPins(order) }
    }

    /// Returns the new profile's name.
    @discardableResult
    func addProfile() -> String {
        var name = ""
        update { name = $0.addProfile(named: "New Profile") }
        return name
    }

    func removeProfile(named name: String) {
        update { $0.removeProfile(named: name) }
    }

    func updateProfile(named name: String, _ change: (inout Profile) -> Void) {
        update { $0.updateProfile(named: name, change) }
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
