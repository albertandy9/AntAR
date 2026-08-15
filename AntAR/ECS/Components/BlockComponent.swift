//
//  BlockComponent.swift
//  AntAR
//

import RealityKit

public struct BlockComponent: Component, Codable {
    /// The complete authored RCP scale. Keeping all three axes is important because path blocks
    /// can be thin/long rather than uniform cubes.
    public var baseScale: SIMD3<Float>
    public var appearProgress: Float

    public init(
        baseScale: SIMD3<Float> = SIMD3<Float>(repeating: 1),
        appearProgress: Float = 0.0
    ) {
        self.baseScale = baseScale
        self.appearProgress = appearProgress
    }
}
