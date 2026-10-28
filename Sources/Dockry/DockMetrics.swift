import DockryCore
import SwiftUI

/// Sizes and orientation the dock's views share, derived from the settings.
struct DockMetrics: Equatable {
    var position: DockPosition
    var iconSize: CGFloat
    /// Scale of an icon right under the pointer; 1 without magnification.
    var magnification: CGFloat
    var showsIndicators: Bool
    var animatesLaunch: Bool

    init(_ settings: DockSettings) {
        position = settings.position
        iconSize = settings.iconSize
        magnification = settings.magnification
        showsIndicators = settings.showsIndicators
        animatesLaunch = settings.animatesLaunch
    }

    var axis: Axis { position.isVertical ? .vertical : .horizontal }

    /// Widgets are designed for 48-point icons and scale with the icon size.
    var unit: CGFloat { iconSize / 48 }

    var spacing: CGFloat { 6 * unit }
    /// Padding before the first item and after the last, along the dock.
    var sidePadding: CGFloat { max(6, 10 * unit) }
    /// Padding between the items and the dock's edge, on the screen-edge side; holds the
    /// running-app dots.
    var edgePadding: CGFloat { max(8, 12 * unit) }
    /// Padding on the side facing the middle of the screen.
    var innerPadding: CGFloat { max(5, 8 * unit) }
    /// Distance between the dock and the screen edge.
    static let margin: CGFloat = 6

    /// Thickness of the dock itself, without magnification.
    var thickness: CGFloat { iconSize + edgePadding + innerPadding }

    /// Thickness of the transparent window that holds the dock: room for magnified icons,
    /// the name label above the hovered icon, a launching icon's bounce and the shadow.
    var panelThickness: CGFloat {
        let tallest = iconSize * max(magnification, 1.5)  // a bounce goes half an icon high
        let label: CGFloat = position.isVertical ? 220 : 36
        return (Self.margin + edgePadding + tallest + label + 12).rounded(.up)
    }

    /// How far from the pointer icons still grow, like the macOS Dock: a few icons each way.
    var magnificationReach: CGFloat { iconSize * 3 }
}

private struct DockMetricsKey: EnvironmentKey {
    static let defaultValue = DockMetrics(DockSettings())
}

extension EnvironmentValues {
    var dockMetrics: DockMetrics {
        get { self[DockMetricsKey.self] }
        set { self[DockMetricsKey.self] = newValue }
    }
}

extension DockPosition {
    /// The side of an icon that faces the middle of the screen, where labels and popovers go.
    var innerEdge: Edge {
        switch self {
        case .bottom: .top
        case .left: .trailing
        case .right: .leading
        }
    }

    /// The side that faces the screen edge, where the running-app dots go.
    var outerEdge: Edge {
        switch self {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }
}
