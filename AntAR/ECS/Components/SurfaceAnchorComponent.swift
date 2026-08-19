//
//  SurfaceAnchorComponent.swift
//  AntAR
//

import RealityKit

enum SurfaceDistanceStatus: Equatable {
    case unavailable
    case tooClose
    case valid
    case tooFar
}

enum SurfaceAnchorRequirements {
    /// The experience is authored for a large tabletop area, not the previous 25 cm patch.
    static let minimumBounds = SIMD2<Float>(repeating: 0.80)
    static let targetCameraDistance: Float = 0.80
    static let cameraDistanceTolerance: Float = 0.20

    static let validCameraDistance: ClosedRange<Float> = (
        targetCameraDistance - cameraDistanceTolerance
    )...(
        targetCameraDistance + cameraDistanceTolerance
    )
}

public struct SurfaceAnchorComponent: Component, Codable {
    public var isLocked: Bool

    public init(isLocked: Bool = false) {
        self.isLocked = isLocked
    }
}
