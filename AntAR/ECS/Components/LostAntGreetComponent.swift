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
    // Set by ARExperienceViewModel.confirmAntDialogueDismissed() once the player has tapped
    // through both of the ant's dialogue lines. LostAntGreetSystem's .releasing phase waits on
    // this (in addition to its own releaseDuration timer) before advancing to .returning, so the
    // ant doesn't shrink back down — and the player can't start searching for the UFO — until the
    // dialogue has actually been read, not just whenever the fixed timer happens to run out.
    public var isDialogueDismissed: Bool

    public init(
        restPosition: SIMD3<Float>,
        risenPosition: SIMD3<Float>,
        phase: LostAntGreetPhase = .arrived,
        phaseElapsed: Float = 0,
        isDialogueDismissed: Bool = false
    ) {
        self.restPosition = restPosition
        self.risenPosition = risenPosition
        self.phase = phase
        self.phaseElapsed = phaseElapsed
        self.isDialogueDismissed = isDialogueDismissed
    }
}
