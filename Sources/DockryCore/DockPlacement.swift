import Foundation
#if canImport(CoreGraphics)
import CoreGraphics  // CGRect's minX and friends; on Linux, Foundation has them
#endif

public enum DockPlacement {
    /// Which screens get a dock, as indexes into `screens` (screen frames in one global
    /// coordinate space, the main screen first). At the bottom, every screen has one. On a
    /// side, only the screen at that far edge of the arrangement does, as with the macOS Dock.
    public static func screens(_ screens: [CGRect], position: DockPosition) -> [Int] {
        let indexes = Array(screens.indices)
        switch position {
        case .bottom:
            return indexes
        // On a tie (screens stacked on top of each other), the earlier one: the main screen
        // if it's among them.
        case .left:
            return indexes.min { screens[$0].minX < screens[$1].minX }.map { [$0] } ?? []
        case .right:
            return indexes.min { screens[$0].maxX > screens[$1].maxX }.map { [$0] } ?? []
        }
    }
}
