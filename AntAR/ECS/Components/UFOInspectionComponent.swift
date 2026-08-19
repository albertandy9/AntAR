//
//  UFOInspectionComponent.swift
//  AntAR
//

import RealityKit

public enum UFOInspectionPhase: String, Codable, Sendable {
    case resting
    case presenting
    case inspecting
    case dismissing
}

/// Local presentation state for inspecting the travelling UFO's underside.
///
/// SwiftUI only requests a phase change. `UFOInspectionSystem` owns all orientation changes and
/// restores the exact world-space orientation captured before inspection.
public struct UFOInspectionComponent: Component, Codable {
    public var phase: UFOInspectionPhase
    public var progress: Float
    public var restOrientationVector: SIMD4<Float>?
    public var inspectionOrientationVector: SIMD4<Float>?

    public init(
        phase: UFOInspectionPhase = .resting,
        progress: Float = 0,
        restOrientationVector: SIMD4<Float>? = nil,
        inspectionOrientationVector: SIMD4<Float>? = nil
    ) {
        self.phase = phase
        self.progress = min(max(progress, 0), 1)
        self.restOrientationVector = restOrientationVector
        self.inspectionOrientationVector = inspectionOrientationVector
    }

    public var isActive: Bool {
        phase != .resting
    }

    public mutating func present() {
        guard phase == .resting else { return }
        phase = .presenting
        progress = 0
        restOrientationVector = nil
        inspectionOrientationVector = nil
    }

    public mutating func dismiss() {
        guard phase == .presenting || phase == .inspecting else { return }
        phase = .dismissing
    }

    public static let transitionDuration: Float = 0.38
}
