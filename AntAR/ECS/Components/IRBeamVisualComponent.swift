//
//  IRBeamVisualComponent.swift
//  AntAR
//

import RealityKit

public enum IRBeamVisualKind: String, Codable, Sendable {
    case emittedWave
    case returnedWave
    case impactGlow
}

/// Identifies a lightweight IR teaching visual.
///
/// Runtime animation changes only transform and `OpacityComponent`; it never replaces the model
/// material during the render loop.
public struct IRBeamVisualComponent: Component, Codable {
    public var kind: IRBeamVisualKind
    public var phaseOffset: Float

    public init(kind: IRBeamVisualKind, phaseOffset: Float = 0) {
        self.kind = kind
        self.phaseOffset = phaseOffset - floor(phaseOffset)
    }
}
