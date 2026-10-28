import AppKit
import DockryCore

/// Fast User Switching: this Mac's other accounts, and switching to them the way the user
/// menu in Control Center does. macOS has no public API for this (the old CGSession tool is
/// gone), so it calls the private login.framework functions that still exist in macOS 15.
enum UserSwitching {
    static func switchTo(_ user: MacUser) {
        if let switchToUser = loginFunction("SACSwitchToUser", as: (@convention(c) (uid_t) -> Int32).self) {
            _ = switchToUser(user.uid)
        } else {
            showLoginWindow()
        }
    }

    /// The login window lists every account, so this still works if switching directly doesn't.
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
