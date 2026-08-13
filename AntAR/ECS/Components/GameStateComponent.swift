//
//  GameStateComponent.swift
//  AntAR
//

import Foundation
import RealityKit


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
