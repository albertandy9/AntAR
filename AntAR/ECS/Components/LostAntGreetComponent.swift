//
//  LostAntGreetComponent.swift
//  AntAR
//

import RealityKit


public enum LostAntGreetPhase: String, Codable, Sendable {
    case arrived
    case waiting
    case rising
    case chatting
    case releasing
    case returning
    case done
}


public struct LostAntGreetComponent: Component, Codable {
    public var phase: LostAntGreetPhase
    public var phaseElapsed: Float
    public var restPosition: SIMD3<Float>
    public var risenPosition: SIMD3<Float>

    public init(
        restPosition: SIMD3<Float>,
        risenPosition: SIMD3<Float>,
        phase: LostAntGreetPhase = .arrived,
        phaseElapsed: Float = 0
    ) {
        self.restPosition = restPosition
        self.risenPosition = risenPosition
        self.phase = phase
        self.phaseElapsed = phaseElapsed
    }
}
