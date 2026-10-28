import Foundation

/// Dockry's own secrets, one file each in Application Support, readable only by the user.
/// Not the keychain: Dockry is ad-hoc signed, so every new build is a different app to the
/// keychain and macOS would ask for the login password after each update.
enum SecretFile {
    private static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Dockry", isDirectory: true)

    static func read(_ name: String) -> String? {
        try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
    }

    static func save(_ value: String, as name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Dockry: couldn't create \(directory.path): \(error)")
        }
        let path = directory.appendingPathComponent(name).path
        if !FileManager.default.createFile(atPath: path, contents: Data(value.utf8), attributes: [.posixPermissions: 0o600]) {
            NSLog("Dockry: couldn't save \(path)")
        }
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}
