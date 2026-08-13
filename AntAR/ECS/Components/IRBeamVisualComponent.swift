//
//  IRBeamVisualComponent.swift
//  AntAR
//

import RealityKit

/// Stores the authored beam's default opacity so IR feedback can be reset reliably.
public struct IRBeamVisualComponent: Component, Codable {
    public var baselineOpacity: Float

    public init(baselineOpacity: Float = 0.18) {
        self.baselineOpacity = baselineOpacity
    }
}
