//
//  AntARECSRegistry.swift
//  AntAR
//

import RealityKit

/// One explicit registration point for custom RealityKit components and systems.
@MainActor
enum AntARECSRegistry {
    private static var hasRegistered = false

    static func register() {
        guard !hasRegistered else { return }
        hasRegistered = true

        GameStateComponent.registerComponent()
        GameEventComponent.registerComponent()
        GameDirectorComponent.registerComponent()
        SceneBindingComponent.registerComponent()
        GameStateGateComponent.registerComponent()
        IRReflectanceComponent.registerComponent()
        PathTileComponent.registerComponent()
        HomeComponent.registerComponent()
        UFOPathFollowerComponent.registerComponent()
        UFOControlComponent.registerComponent()
        IRSensorComponent.registerComponent()
        IRSensorArrayComponent.registerComponent()
        IRBeamVisualComponent.registerComponent()

        GameStateMachineSystem.registerSystem()
        SceneBindingSystem.registerSystem()
        GameStateVisibilitySystem.registerSystem()
        IRSimulationSystem.registerSystem()
        UFOControlSystem.registerSystem()
        UFOPathFollowingSystem.registerSystem()
        CompletionPresentationSystem.registerSystem()
    }
}
