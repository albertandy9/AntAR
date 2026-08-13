//
//  GameStateVisibilitySystem.swift
//  AntAR
//

import RealityKit

/// Applies visibility gates authored on phase-group roots in the one complete scene.
public struct GameStateVisibilitySystem: System {
    public static let dependencies: [SystemDependency] = [.after(SceneBindingSystem.self)]

    private static let directorQuery = EntityQuery(where: .has(GameStateComponent.self))
    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        guard let director = context.entities(
            matching: Self.directorQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true }),
        let gameState = director.components[GameStateComponent.self]?.current,
        let root = director.parent else {
            return
        }

        // Do not use an EntityQuery here. As soon as a gate hides its entity, a query no longer
        // returns it and the next story state would be unable to reveal it.
        for entity in root.antarDescendants() {
            guard let gate = entity.components[GameStateGateComponent.self] else { continue }

            // A route tile has two independent conditions: the story must be travelling and the
            // player/system must have placed this particular tile. This preserves future drag
            // placement support while keeping all default tiles hidden after completion.
            if let tile = entity.components[PathTileComponent.self] {
                entity.isEnabled = gate.isVisible(in: gameState) && tile.isPlaced
            } else {
                entity.isEnabled = gate.isVisible(in: gameState)
            }
        }
    }
}
