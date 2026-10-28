// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Dockry",
    platforms: [.macOS(.v14)],
    targets: [
        // Platform-independent logic (profiles, dock layout, shortcut parsing). Builds and tests on Linux too.
        .target(name: "DockryCore"),
        // The macOS app: AppKit/SwiftUI UI and the system integrations.
        .executableTarget(name: "Dockry", dependencies: ["DockryCore"]),
        .testTarget(name: "DockryCoreTests", dependencies: ["DockryCore"]),
    ]
)
