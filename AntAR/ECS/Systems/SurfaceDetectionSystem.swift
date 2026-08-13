//
//  SurfaceDetectionSystem.swift
//  AntAR
//

import RealityKit
public struct SurfaceDetectionSystem: System {
    private static let surfaceQuery = EntityQuery(where: .has(SurfaceAnchorComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for surface in context.entities(matching: Self.surfaceQuery, updatingSystemWhen: .rendering) {
            guard surface.isAnchored,
                  var surfaceState = surface.components[SurfaceAnchorComponent.self],
                  !surfaceState.isLocked else {
                continue
            }

            surfaceState.isLocked = true
            surface.components[SurfaceAnchorComponent.self] = surfaceState
        }
    }
}
