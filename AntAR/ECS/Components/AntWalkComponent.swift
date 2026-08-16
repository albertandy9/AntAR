//
//  AntWalkComponent.swift
//  AntAR
//

import RealityKit

public struct AntWalkComponent: Component, Codable {
    public var startPosition: SIMD3<Float>
    public var targetPosition: SIMD3<Float>
    public var progress: Float
    public var disappearsOnArrival: Bool
    public var hasStartedAnimation: Bool

    public init(
        startPosition: SIMD3<Float>,
        targetPosition: SIMD3<Float>,
        disappearsOnArrival: Bool,
        progress: Float = 0,
        hasStartedAnimation: Bool = false
    ) {
        self.startPosition = startPosition
        self.targetPosition = targetPosition
        self.disappearsOnArrival = disappearsOnArrival
        self.progress = progress
        self.hasStartedAnimation = hasStartedAnimation
    }
}
