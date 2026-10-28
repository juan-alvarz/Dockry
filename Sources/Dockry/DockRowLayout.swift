import DockryCore
import SwiftUI

/// Marks the view the layout stretches behind its items as the dock's background.
struct DockBackgroundKey: LayoutValueKey {
    static let defaultValue = false
}

/// Marks items that grow with magnification: app icons, as in the macOS Dock.
struct MagnifiesKey: LayoutValueKey {
    static let defaultValue = false
}

/// Lays the dock's items out along the screen edge, magnifying them around the pointer, with
/// the dock's background behind them. Its own size is always the unmagnified one, so the
/// dock doesn't move while magnified icons grow out of it, as in the macOS Dock.
struct DockRowLayout: Layout {
    var metrics: DockMetrics
    /// The pointer's position along the dock, in this layout's coordinates; nil when it isn't
    /// over the dock.
    var pointer: CGFloat?
    /// How far magnification has kicked in, from 0 to 1. Animating it is what makes icons
    /// swell as the pointer arrives and settle back when it leaves, like the macOS Dock,
    /// instead of jumping.
    var amount: CGFloat = 1

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    private var isHorizontal: Bool { metrics.axis == .horizontal }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = items(subviews).map { $0.sizeThatFits(.unspecified) }
        let length = sizes.map(mainLength).reduce(0, +)
            + metrics.spacing * CGFloat(max(sizes.count - 1, 0)) + 2 * metrics.sidePadding
        let thickness = (sizes.map(crossLength).max() ?? 0) + metrics.edgePadding + metrics.innerPadding
        return isHorizontal ? CGSize(width: length, height: thickness) : CGSize(width: thickness, height: length)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let items = items(subviews)
        let sizes = items.map { $0.sizeThatFits(.unspecified) }
        let placement = DockMagnification.place(
            zip(items, sizes).map { DockMagnification.Item(length: Double(mainLength($1)), magnifies: $0[MagnifiesKey.self]) },
            spacing: metrics.spacing,
            pointer: pointer.map { Double($0 - metrics.sidePadding) },
            magnification: 1 + (metrics.magnification - 1) * amount,
            reach: metrics.magnificationReach)

        let mainOrigin = (isHorizontal ? bounds.minX : bounds.minY) + metrics.sidePadding
        for (index, item) in items.enumerated() {
            let scale = CGFloat(placement.scales[index])
            let size = CGSize(width: sizes[index].width * scale, height: sizes[index].height * scale)
            let main = mainOrigin + CGFloat(placement.starts[index])
            // Items sit against the screen-edge side and grow toward the middle of the screen.
            let origin: CGPoint
            switch metrics.position {
            case .bottom: origin = CGPoint(x: main, y: bounds.maxY - metrics.edgePadding - size.height)
            case .left: origin = CGPoint(x: bounds.minX + metrics.edgePadding, y: main)
            case .right: origin = CGPoint(x: bounds.maxX - metrics.edgePadding - size.width, y: main)
            }
            item.place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(size))
        }

        // The background follows the (possibly magnified) row, at the dock's normal thickness.
        guard let background = subviews.first(where: { $0[DockBackgroundKey.self] }) else { return }
        let first = mainOrigin + CGFloat(placement.starts.first ?? 0)
        var last = first
        if let lastIndex = items.indices.last {
            last = mainOrigin + CGFloat(placement.starts[lastIndex])
                + mainLength(sizes[lastIndex]) * CGFloat(placement.scales[lastIndex])
        }
        let start = first - metrics.sidePadding
        let length = last + metrics.sidePadding - start
        let frame = isHorizontal
            ? CGRect(x: start, y: bounds.minY, width: length, height: bounds.height)
            : CGRect(x: bounds.minX, y: start, width: bounds.width, height: length)
        background.place(at: frame.origin, anchor: .topLeading, proposal: ProposedViewSize(frame.size))
    }

    private func items(_ subviews: Subviews) -> [LayoutSubviews.Element] {
        subviews.filter { !$0[DockBackgroundKey.self] }
    }

    private func mainLength(_ size: CGSize) -> CGFloat { isHorizontal ? size.width : size.height }
    private func crossLength(_ size: CGSize) -> CGFloat { isHorizontal ? size.height : size.width }
}
