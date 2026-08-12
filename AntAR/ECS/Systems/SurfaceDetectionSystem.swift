//
//  SurfaceDetectionSystem.swift
//  AntAR
//

import RealityKit

/// Converts ARKit's anchored horizontal-plane result into the first game-flow event.
public struct SurfaceDetectionSystem: System {
    private static let surfaceQuery = EntityQuery(where: .has(SurfaceAnchorComponent.self))
    private static let directorQuery = EntityQuery(
        where: .has(GameDirectorComponent.self) && .has(GameEventComponent.self)
    )

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        var didLockSurface = false

        for surface in context.entities(matching: Self.surfaceQuery, updatingSystemWhen: .rendering) {
            guard surface.isAnchored,
                  var surfaceState = surface.components[SurfaceAnchorComponent.self],
                  !surfaceState.isLocked else {
                continue
            }

            surfaceState.isLocked = true
            surface.components[SurfaceAnchorComponent.self] = surfaceState
            didLockSurface = true
        }

        guard didLockSurface else { return }

        for director in context.entities(matching: Self.directorQuery, updatingSystemWhen: .rendering) {
            guard var events = director.components[GameEventComponent.self] else { continue }
            events.enqueue(.surfaceLocked)
            director.components[GameEventComponent.self] = events
        }
    }
}
