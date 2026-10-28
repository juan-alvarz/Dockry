// CI only: calls login.framework's SACSwitchToUser the same way UserSwitching.swift does.
import Foundation

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 2, let name = arguments.first, let uid = arguments.last else {
    fatalError("usage: switch-user.swift <name> <uid>")
}
let login = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_LAZY)
guard let symbol = dlsym(login, "SACSwitchToUser") else { fatalError("SACSwitchToUser not found") }
let switchToUser = unsafeBitCast(symbol, to: (@convention(c) (CFDictionary) -> Int32).self)
let attributes = ["dsAttrTypeStandard:RecordName": [name], "dsAttrTypeStandard:UniqueID": [uid]]
print("SACSwitchToUser returned", switchToUser(attributes as CFDictionary))
