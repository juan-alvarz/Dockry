import Foundation
import Security

/// Dockry's own secrets in the login keychain. Keychain calls can block (on a prompt, or on
/// securityd), so they run off the main thread.
enum Keychain {
    private static let service = "io.github.juan-alvarz.Dockry"

    static func read(_ account: String) async -> String? {
        await onBackground {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
            ]
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data
            else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }

    static func save(_ value: String, for account: String) async {
        await onBackground {
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(item as CFDictionary)
            var added = item
            added[kSecValueData as String] = Data(value.utf8)
            let status = SecItemAdd(added as CFDictionary, nil)
            if status != errSecSuccess {
                NSLog("Dockry: couldn't save \(account) to the keychain: \(status)")
            }
        }
    }

    static func delete(_ account: String) async {
        await onBackground {
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(item as CFDictionary)
        }
    }

    // Task.detached isn't enough: it can still run on the main thread's executor in practice
    // (Dockry's Claude usage widget froze the dock that way), so use a global queue.
    private static func onBackground<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { continuation.resume(returning: work()) }
        }
    }
}
