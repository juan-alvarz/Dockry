import Foundation

/// Reads and writes the profiles as pretty-printed JSON, so they can be edited by hand.
public struct ProfileFile {
    public let url: URL

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dockry", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }

    public init(url: URL = ProfileFile.defaultURL) {
        self.url = url
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// A missing file gives the default profiles. An unreadable one also gives the defaults,
    /// but is first moved to `profiles.json.broken` so saving can't overwrite the user's edits;
    /// the decoding error is returned so it can be shown.
    public func load() -> (library: ProfileLibrary, error: Error?) {
        guard exists else { return (ProfileLibrary(), nil) }
        do {
            let data = try Data(contentsOf: url)
            return (try JSONDecoder().decode(ProfileLibrary.self, from: data), nil)
        } catch {
            let backup = url.appendingPathExtension("broken")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return (ProfileLibrary(), error)
        }
    }

    public func save(_ library: ProfileLibrary) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: url, options: .atomic)
    }
}
