// CI only: calls login.framework's SACSwitchToUser the same way UserSwitching.swift does.
import Foundation

guard let uid = CommandLine.arguments.dropFirst().first.flatMap({ uid_t($0) }) else {
    fatalError("usage: switch-user.swift <uid>")
}
let login = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_LAZY)
guard let symbol = dlsym(login, "SACSwitchToUser") else { fatalError("SACSwitchToUser not found") }
let switchToUser = unsafeBitCast(symbol, to: (@convention(c) (uid_t) -> Int32).self)
print("SACSwitchToUser returned", switchToUser(uid))
