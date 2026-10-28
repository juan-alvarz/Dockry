// CI only: calls login.framework's SACSwitchToLoginWindow the same way UserSwitching.swift does.
import Foundation

let login = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_LAZY)
guard let symbol = dlsym(login, "SACSwitchToLoginWindow") else { fatalError("SACSwitchToLoginWindow not found") }
let switchToLoginWindow = unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
print("SACSwitchToLoginWindow returned", switchToLoginWindow())
