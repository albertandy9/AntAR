//
//  PathTileComponent.swift
//  AntAR
//

import RealityKit

/// Runtime data for one of the reusable, scene-authored route tiles.
///
/// The footprint is cached once when the block is placed. Sensor simulation transforms its
/// sample point into this entity's local space, avoiding an expensive `visualBounds` traversal
/// for every sensor on every rendered frame.
public struct PathTileComponent: Component, Codable {
    public var order: Int
    public var isPlaced: Bool
    public var footprintCenter: SIMD2<Float>
    public var footprintHalfExtents: SIMD2<Float>

    public init(
        order: Int,
        isPlaced: Bool = false,
        footprintCenter: SIMD2<Float> = .zero,
        footprintHalfExtents: SIMD2<Float> = SIMD2<Float>(repeating: 0.05)
    ) {
        self.order = order
        self.isPlaced = isPlaced
        self.footprintCenter = footprintCenter
        self.footprintHalfExtents = SIMD2<Float>(
            max(footprintHalfExtents.x, 0.005),
            max(footprintHalfExtents.y, 0.005)
        )
    }
}
