//
//  GameStateComponent.swift
//  AntAR
//

import Foundation
import RealityKit

/// Runtime state attached exactly once, to the non-visual `GameDirector` entity.
///
/// This is the ECS home for the `GameState` enum. Feature entities keep their own focused
/// components (for example `UFOStateComponent` or `PathTileComponent`) and report a `GameEvent`
/// when they complete a global story beat.
public struct GameStateComponent: Component, Codable {
    public private(set) var current: GameState
    public private(set) var previous: GameState?
    public private(set) var elapsedTime: TimeInterval

    public init(initialState: GameState = .scanningTable) {
        current = initialState
        previous = nil
        elapsedTime = 0
    }

    mutating func advanceTime(by deltaTime: TimeInterval) {
        elapsedTime += deltaTime
    }

    mutating func transition(to nextState: GameState) {
        previous = current
        current = nextState
        elapsedTime = 0
    }
}
