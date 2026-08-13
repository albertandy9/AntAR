//
//  CompletionPresentationSystem.swift
//  AntAR
//

import RealityKit

/// Reveals the success group after the global state machine enters `completed`.
///
/// `Phase_Complete` is preferred. The legacy finish markers in the existing scene are supported
/// as a temporary fallback so the end of the current scene is visible before the artist groups
/// them under the named phase root.
public struct CompletionPresentationSystem: System {
    private static let directorQuery = EntityQuery(where: .has(GameStateComponent.self))
    private static let homeQuery = EntityQuery(where: .has(HomeComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        guard let director = context.entities(
            matching: Self.directorQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true }),
        director.components[GameStateComponent.self]?.current == .completed,
        let root = director.parent else {
            return
        }

        if let group = root.antarDescendant(named: AntARSceneNames.completionGroup) {
            group.isEnabled = true
        } else {
            for name in AntARSceneNames.legacyCompletionEntities {
                root.antarDescendant(named: name)?.isEnabled = true
            }
        }

        guard let ufo = root.antarDescendant(named: AntARSceneNames.travelUFO),
              let home = context.entities(
                matching: Self.homeQuery,
                updatingSystemWhen: .rendering
              ).first(where: { _ in true }) else {
            return
        }

        // Keep the final location at the nest even if a completion animation is added later.
        var finalPosition = home.position(relativeTo: nil)
        finalPosition.y += UFOPathFollowerComponent.hoverHeight
        ufo.setPosition(finalPosition, relativeTo: nil)
    }
}
