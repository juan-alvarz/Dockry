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

    /// Picks up changes made to profiles.json by hand.
    func reload() {
        let result = file.load()
        library = result.library
        loadError = result.error
    }

    /// Opens profiles.json in the user's app for JSON, or shows it in Finder if there's none.
    func openFile() {
        if !file.exists {
            save(library)
        }
        if !NSWorkspace.shared.open(file.url) {
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
        }
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
