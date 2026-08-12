//
//  SurfaceAnchorComponent.swift
//  AntAR
//

import RealityKit

/// Runtime data for the plane anchor that represents the scanned desk.
/// Visual scan feedback remains a child entity authored in Reality Composer Pro; this component
/// is only concerned with whether ARKit has supplied a stable surface anchor.
public struct SurfaceAnchorComponent: Component, Codable {
    public var isLocked: Bool

    public init(isLocked: Bool = false) {
        self.isLocked = isLocked
    }
}
