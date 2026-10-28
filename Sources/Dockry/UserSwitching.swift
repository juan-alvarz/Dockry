import AppKit
import DockryCore

/// Fast User Switching: this Mac's other accounts, and switching to them the way the user
/// menu in Control Center does. macOS has no public API for this (the old CGSession tool is
/// gone), so it calls private login.framework functions that still exist in macOS 15.
enum UserSwitching {
    /// SACSwitchToUser takes a dictionary of the account's directory attributes (it checks
    /// for a CFDictionary and hands it to loginwindow's Fast User Switching). CI confirms it
    /// takes this session off the screen; that it then lands on `user` rather than on the
    /// general login window needs that user to be logged in, which CI can't do.
    static func switchTo(_ user: MacUser) {
        let attributes = [
            "dsAttrTypeStandard:RecordName": [user.name],
            "dsAttrTypeStandard:UniqueID": [String(user.uid)],
        ]
        guard let switchToUser = loginFunction("SACSwitchToUser", as: (@convention(c) (CFDictionary) -> Int32).self),
              switchToUser(attributes as CFDictionary) == 0
        else {
            showLoginWindow()
            return
        }
    }

    static func showLoginWindow() {
        _ = loginFunction("SACSwitchToLoginWindow", as: (@convention(c) () -> Int32).self)?()
    }

    private static let loginFramework = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_LAZY)

    private static func loginFunction<Function>(_ name: String, as type: Function.Type) -> Function? {
        guard let loginFramework, let symbol = dlsym(loginFramework, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }
}

/// The accounts you can switch to: everyone's but your own.
@MainActor
final class MacUsers: ObservableObject {
    static let shared = MacUsers()

    @Published private(set) var others: [MacUser] = []

    private init() {
        Task {
            let me = getuid()
            others = await Self.load().filter { $0.uid != me }
        }
    }

    private static func load() async -> [MacUser] {
        await Task.detached {
            let command = MacUser.directoryListingCommand
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return [] }
            // Read before waiting: the listing is bigger than the pipe's buffer.
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return MacUser.parseDirectoryListing(data)
        }.value
    }
}
