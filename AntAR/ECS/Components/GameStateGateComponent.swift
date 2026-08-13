//
//  GameStateGateComponent.swift
//  AntAR
//

import RealityKit

/// Scene-authored visibility rule for an entity or whole entity group.
///
/// Put this on the root of each phase group in Reality Composer Pro. The entity stays in one
/// complete scene and is simply enabled when the story reaches one of its allowed states.
public struct GameStateGateComponent: Component, Codable {
    public var visibleDuring: [GameState]

    public init(visibleDuring: [GameState]) {
        self.visibleDuring = visibleDuring
    }

    func isVisible(in gameState: GameState) -> Bool {
        visibleDuring.contains(gameState)
    }
}
