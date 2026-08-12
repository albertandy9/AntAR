//
//  AntBehaviorComponent.swift
//  AntAR
//
//  Step 1: Define Component (Data Struct). Attach to every `Ant` / `LostAnt` entity.
//

import RealityKit

public enum AntState: String, Codable, CaseIterable, Sendable {
    case idle
    case walk
    case onHand
    case lost
    case rescued
}

public struct AntBehaviorComponent: Component, Codable {
    // TUNABLE IN RC PRO
    public var state: AntState = .idle
    // TUNABLE IN RC PRO — walking speed in meters/second, used by AntNavigationSystem.
    public var speed: Float = 0.15
    // TUNABLE IN RC PRO — false only on the LostAnt entity (the one without an antenna).
    public var hasAntenna: Bool = true

    public init() {}
}
