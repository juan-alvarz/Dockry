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
    /// plus the decoding error so it can be shown; the file itself is left alone.
    public func load() -> (library: ProfileLibrary, error: Error?) {
        guard exists else { return (ProfileLibrary(), nil) }
        do {
            let data = try Data(contentsOf: url)
            return (try JSONDecoder().decode(ProfileLibrary.self, from: data), nil)
        } catch {
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
