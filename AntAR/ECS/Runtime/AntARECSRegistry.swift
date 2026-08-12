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

        GameStateMachineSystem.registerSystem()
        SurfaceDetectionSystem.registerSystem()
    }
}
