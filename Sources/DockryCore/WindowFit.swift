import Foundation

/// Where a window goes so it stays out of the dock's space, as with the macOS Dock: a
/// window never sits behind the dock.
public enum WindowFit {
    /// The frame for `window` so it stays inside `allowed` on the dock's side: a window that
    /// fits is moved out of the dock's way at its size; one too big for the space left (a
    /// zoomed window, say) is cut to fill it. The other sides are left alone, so a window
    /// the user pushed partly off screen stays that way. In AppKit coordinates (origin at the
    /// bottom left), like `allowed`.
    public static func frame(_ window: CGRect, avoiding position: DockPosition, allowed: CGRect) -> CGRect {
        var frame = window
        switch position {
        case .bottom:
            guard frame.minY < allowed.minY else { return window }
            frame.size.height = min(frame.height, allowed.height)
            frame.origin.y = allowed.minY
        case .left:
            guard frame.minX < allowed.minX else { return window }
            frame.size.width = min(frame.width, allowed.width)
            frame.origin.x = allowed.minX
        case .right:
            guard frame.maxX > allowed.maxX else { return window }
            frame.size.width = min(frame.width, allowed.width)
            frame.origin.x = allowed.maxX - frame.width
        }
        return frame
    }

    /// The area windows may use on a screen whose usable area (without the menu bar and a
    /// showing macOS Dock) is `visible`, with a dock `thickness` points thick against the
    /// `position` edge of `dockArea`, the strip Dockry's dock lives in.
    public static func allowedArea(visible: CGRect, dockArea: CGRect, position: DockPosition, thickness: CGFloat) -> CGRect {
        var allowed = visible
        switch position {
        case .bottom:
            let edge = max(allowed.minY, dockArea.minY + thickness)
            allowed.size.height = max(allowed.maxY - edge, 0)
            allowed.origin.y = edge
        case .left:
            let edge = max(allowed.minX, dockArea.minX + thickness)
            allowed.size.width = max(allowed.maxX - edge, 0)
            allowed.origin.x = edge
        case .right:
            let edge = min(allowed.maxX, dockArea.maxX - thickness)
            allowed.size.width = max(edge - allowed.minX, 0)
        }
        return allowed
    }
}
