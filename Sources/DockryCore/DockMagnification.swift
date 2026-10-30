import Foundation

/// The Dock's magnification: icons near the pointer grow, the one under it the most, and
/// the row stretches around the pointer so the spot under it stays put.
public enum DockMagnification {
    public struct Item: Equatable {
        /// Length along the dock at normal size.
        public var length: Double
        public var magnifies: Bool
        /// Half the length around its center that counts as right under the pointer, so a
        /// wide item (a widget) grows fully anywhere along it, not only at its center.
        public var plateau: Double

        public init(length: Double, magnifies: Bool, plateau: Double = 0) {
            self.length = length
            self.magnifies = magnifies
            self.plateau = plateau
        }
    }

    public struct Placement: Equatable {
        /// Where each item starts along the dock, in the same coordinates as the normal
        /// layout (the first item starts at 0 when nothing is magnified).
        public var starts: [Double]
        public var scales: [Double]
    }

    /// - Parameters:
    ///   - pointer: Position of the pointer along the dock, in normal-layout coordinates, or
    ///     nil when it isn't over the dock.
    ///   - magnification: Scale of an item right under the pointer.
    ///   - reach: How far from the pointer items still grow a little.
    public static func place(
        _ items: [Item], spacing: Double, pointer: Double?, magnification: Double, reach: Double
    ) -> Placement {
        var normalStarts: [Double] = []
        var position = 0.0
        for item in items {
            normalStarts.append(position)
            position += item.length + spacing
        }
        guard let pointer, magnification > 1, reach > 0 else {
            return Placement(starts: normalStarts, scales: items.map { _ in 1 })
        }

        let scales = zip(items, normalStarts).map { item, start -> Double in
            guard item.magnifies else { return 1 }
            let distance = max(abs(pointer - (start + item.length / 2)) - item.plateau, 0)
            guard distance < reach else { return 1 }
            // A smooth bump: full size at the pointer, back to normal at `reach`.
            let closeness = (cos(.pi * distance / reach) + 1) / 2
            return 1 + (magnification - 1) * closeness
        }

        var starts: [Double] = []
        position = 0
        // Where the pointer's spot ends up once items before (and under) it have grown.
        var stretchedPointer = pointer
        for (index, item) in items.enumerated() {
            starts.append(position)
            let growth = item.length * (scales[index] - 1)
            let covered = item.length > 0 ? ((pointer - normalStarts[index]) / item.length).clamped(to: 0...1) : 0
            stretchedPointer += growth * covered
            position += item.length * scales[index] + spacing
        }
        let shift = pointer - stretchedPointer
        return Placement(starts: starts.map { $0 + shift }, scales: scales)
    }
}
