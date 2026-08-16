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
        SurfaceAnchorComponent.registerComponent()
        UFOComponent.registerComponent()
        HapticCueComponent.registerComponent()
        SoundCueComponent.registerComponent()
        UFODescendComponent.registerComponent()
        AntBoardComponent.registerComponent()
        UFOAscendComponent.registerComponent()
        BlockComponent.registerComponent()
        PlayerCameraComponent.registerComponent()
        BlockCollectibleComponent.registerComponent()
        IRReflectanceComponent.registerComponent()
        PathTileComponent.registerComponent()
        HomeComponent.registerComponent()
        UFOPathFollowerComponent.registerComponent()
        UFOControlComponent.registerComponent()
        IRSensorComponent.registerComponent()
        IRSensorArrayComponent.registerComponent()
        IRBeamVisualComponent.registerComponent()
        BlockPlacementGuideComponent.registerComponent()
        UFOInspectionComponent.registerComponent()

        GameStateMachineSystem.registerSystem()
        SurfaceDetectionSystem.registerSystem()
        UFOAppearanceSystem.registerSystem()
        HapticFeedbackSystem.registerSystem()
        SoundCueSystem.registerSystem()
        UFODescendSystem.registerSystem()
        AntBoardSystem.registerSystem()
        UFOAscendSystem.registerSystem()
        BlockAppearanceSystem.registerSystem()
        BlockPlacementGuideSystem.registerSystem()
        BlockProximitySystem.registerSystem()
        IRSimulationSystem.registerSystem()
        UFOControlSystem.registerSystem()
        UFOPathFollowingSystem.registerSystem()
        UFOInspectionSystem.registerSystem()
        CompletionPresentationSystem.registerSystem()
    }
}
