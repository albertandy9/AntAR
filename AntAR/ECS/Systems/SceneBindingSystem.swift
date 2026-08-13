//
//  SceneBindingSystem.swift
//  AntAR
//

import RealityKit

/// Binds state-10/11 components to entities from `Scene.usda` exactly once after it loads.
///
/// No gameplay geometry is created here: the complete scene is authored in RC Pro. The only
/// dynamic children are the 2…8 sensor beam visuals required by sensor tuning.
public struct SceneBindingSystem: System {
    private static let directorQuery = EntityQuery(where: .has(GameDirectorComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for director in context.entities(matching: Self.directorQuery, updatingSystemWhen: .rendering) {
            guard let root = director.parent else { continue }
            bindSceneIfNeeded(root: root)
        }
    }

    private func bindSceneIfNeeded(root: Entity) {
        bindFocusedPhaseVisibility(root: root)

        if let ufo = root.antarDescendant(named: AntARSceneNames.travelUFO),
           ufo.components[UFOPathFollowerComponent.self] == nil {
            ufo.components.set(UFOPathFollowerComponent())
            ufo.components.set(IRSensorArrayComponent())
            ufo.components.set(SceneBindingComponent(role: .travelUFO))
            ufo.components.set(
                GameStateGateComponent(
                    visibleDuring: [.ufoTravelling, .completed]
                )
            )
            IRSensorFactory.rebuildSensors(on: ufo, sensorCount: 2)
        }

        if let home = root.antarDescendant(named: AntARSceneNames.home),
           home.components[HomeComponent.self] == nil {
            home.components.set(HomeComponent())
            home.components.set(SceneBindingComponent(role: .home))
            home.components.set(
                GameStateGateComponent(
                    visibleDuring: [.ufoTravelling, .completed]
                )
            )
        }

        for (index, name) in AntARSceneNames.pathTiles.enumerated() {
            guard let tile = root.antarDescendant(named: name),
                  tile.components[PathTileComponent.self] == nil else {
                continue
            }

            // This focused build starts at state 10, so the four existing scene slots form the
            // ready-to-run default route. Future block-placement work can still move, replace,
            // or hide these exact same entities through `configurePathTile`.
            tile.components.set(PathTileComponent(order: index + 1, isPlaced: true))
            tile.components.set(IRReflectanceComponent.darkPath)
            tile.components.set(SceneBindingComponent(role: pathTileRole(for: index)))
            tile.components.set(GameStateGateComponent(visibleDuring: [.ufoTravelling]))
            tile.isEnabled = true
        }

        let completionGroup = root.antarDescendant(named: AntARSceneNames.completionGroup)
        if let completionGroup,
           completionGroup.components[SceneBindingComponent.self] == nil {
            completionGroup.components.set(SceneBindingComponent(role: .completionGroup))
            completionGroup.components.set(GameStateGateComponent(visibleDuring: [.completed]))
            completionGroup.isEnabled = false
        }

        prepareTravelUFOAtPickupFinish(root: root)
    }

    /// State 10 continues exactly where the pickup UFO from state 6 finished. `finish_ufo` is an
    /// authored transform marker: it is loaded but remains invisible in every game state.
    private func prepareTravelUFOAtPickupFinish(root: Entity) {
        guard let ufo = root.antarDescendant(named: AntARSceneNames.travelUFO),
              let follower = ufo.components[UFOPathFollowerComponent.self],
              follower.state == .idle,
              let finishMarker = root.antarDescendant(
                named: AntARSceneNames.pickupUFOFinishMarker
              ) else {
            return
        }

        ufo.setTransformMatrix(finishMarker.transformMatrix(relativeTo: ufo.parent), relativeTo: ufo.parent)

        var updatedFollower = follower
        updatedFollower.routeStartPosition = finishMarker.position(relativeTo: nil)
        ufo.components[UFOPathFollowerComponent.self] = updatedFollower
    }

    /// This project only owns the post-pickup flow (states 10 and 11). The source scene still
    /// contains earlier-phase models, and their USD `active` flags are not a dependable runtime
    /// phase contract. Gate every top-level authored entity so those models cannot leak into the
    /// travel scene just because the entire scene was loaded at once.
    private func bindFocusedPhaseVisibility(root: Entity) {
        // `Entity(named:in:)` may return a loader container around the USD default prim. Never
        // infer the authored root from a generic "Root" name: if the container is gated, every
        // child disappears. `ufo_jalan` is a known direct child of the authored root, so its
        // parent is the stable and unambiguous entity to gate.
        guard let travelUFO = root.antarDescendant(named: AntARSceneNames.travelUFO),
              let authoredRoot = travelUFO.parent else {
            return
        }

        for entity in authoredRoot.children {
            guard entity.components[GameStateGateComponent.self] == nil else { continue }

            if entity.name == AntARSceneNames.pickupUFOFinishMarker {
                entity.components.set(GameStateGateComponent(visibleDuring: []))
            } else if AntARSceneNames.legacyCompletionEntities.contains(entity.name) {
                entity.components.set(GameStateGateComponent(visibleDuring: [.completed]))
            } else if AntARSceneNames.ufoTravelRootEntities.contains(entity.name) {
                // The detailed bindings below supply the same rule plus their specialised ECS
                // components. This early gate prevents a one-frame flash on the first render.
                entity.components.set(
                    GameStateGateComponent(
                        visibleDuring: entity.name == AntARSceneNames.travelUFO || entity.name == AntARSceneNames.home
                            ? [.ufoTravelling, .completed]
                            : [.ufoTravelling]
                    )
                )
            } else {
                // Intro ants, pickup UFO, scattered blocks, unused background, and environment
                // helpers do not belong to this team's two-state slice.
                entity.components.set(GameStateGateComponent(visibleDuring: []))
            }
        }
    }

    private func pathTileRole(for index: Int) -> SceneEntityRole {
        switch index {
        case 0: .pathTile1
        case 1: .pathTile2
        case 2: .pathTile3
        default: .pathTile4
        }
    }
}
