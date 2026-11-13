import Foundation

/// Where another profile's window waits, and where it comes back to. macOS won't move a
/// window wholly off screen, so a parked window keeps one point on a screen, at a corner
/// where the rest of it is on no screen. In AppKit coordinates (origin at the bottom left).
public enum WindowParking {
    /// A window almost entirely off every screen.
    public static func isParked(_ frame: CGRect, screens: [CGRect]) -> Bool {
        visibleArea(of: frame, on: screens) < frame.width * frame.height * 0.05
    }

    /// The frame a window of `size` parks at: under a bottom corner of a screen, with one
    /// point of it on that screen and as little as possible on any other. The corner of all
    /// the screens together won't do: with screens of different heights it can be on none,
    /// and macOS refuses the move. Nil without screens.
    public static func spot(for size: CGSize, screens: [CGRect]) -> CGRect? {
        // Rightmost screen and right corner first, where windows parked before this.
        let candidates = screens.sorted { $0.maxX > $1.maxX }.flatMap { screen in
            [screen.maxX - 1, screen.minX - size.width + 1].map { x in
                CGRect(x: x, y: screen.minY - size.height + 1, width: size.width, height: size.height)
            }
        }
        return candidates
            .filter { visibleArea(of: $0, on: screens) > 0 }
            .min { visibleArea(of: $0, on: screens) < visibleArea(of: $1, on: screens) }
    }

    /// Where a window parked from `home` comes back to: `home`, or the middle of the first
    /// screen when `home` is on no screen any more (its screen was unplugged).
    public static func home(_ home: CGRect, screens: [CGRect]) -> CGRect {
        guard let screen = screens.first, isParked(home, screens: screens) else { return home }
        // A window taller than the screen keeps its title bar on it.
        return CGRect(
            x: screen.minX + max((screen.width - home.width) / 2, 0),
            y: screen.maxY - home.height - max((screen.height - home.height) / 2, 0),
            width: home.width, height: home.height)
    }

    private static func visibleArea(of frame: CGRect, on screens: [CGRect]) -> CGFloat {
        screens.reduce(0) { total, screen in
            let part = screen.intersection(frame)
            return total + (part.isNull ? 0 : part.width * part.height)
        }
    }
}
