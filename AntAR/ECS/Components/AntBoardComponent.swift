//
//  AntBoardComponent.swift
//  AntAR
//

import RealityKit

public struct AntBoardComponent: Component, Codable {
    public var startPosition: SIMD3<Float>
    public var targetPosition: SIMD3<Float>
    public var progress: Float

    public init(startPosition: SIMD3<Float>, targetPosition: SIMD3<Float>, progress: Float = 0) {
        self.startPosition = startPosition
        self.targetPosition = targetPosition
        self.progress = progress
    }
}
