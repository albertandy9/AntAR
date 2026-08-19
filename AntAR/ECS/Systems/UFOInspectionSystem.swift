//
//  UFOInspectionSystem.swift
//  AntAR
//

import RealityKit
import simd

/// Pauses the travelling UFO and presents its underside toward the tracked camera for sensor
/// configuration. Camera-facing orientation is sampled once, then frozen until inspection ends.
public struct UFOInspectionSystem: System {
    public static let dependencies: [SystemDependency] = [
        .after(UFOPathFollowingSystem.self)
    ]

    private static let ufoQuery = EntityQuery(
        where: .has(UFOPathFollowerComponent.self) && .has(UFOInspectionComponent.self)
    )
    private static let cameraQuery = EntityQuery(where: .has(PlayerCameraComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let camera = context.entities(
            matching: Self.cameraQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true })

        let deltaTime = Float(context.deltaTime)
        for ufo in context.entities(matching: Self.ufoQuery, updatingSystemWhen: .rendering) {
            guard var inspection = ufo.components[UFOInspectionComponent.self],
                  inspection.isActive else {
                continue
            }

            if inspection.restOrientationVector == nil {
                inspection.restOrientationVector = ufo.orientation(relativeTo: nil).vector
            }
            guard let restVector = inspection.restOrientationVector else { continue }

            let restOrientation = simd_quatf(
                ix: restVector.x,
                iy: restVector.y,
                iz: restVector.z,
                r: restVector.w
            )
            if inspection.inspectionOrientationVector == nil {
                guard let camera else { continue }
                inspection.inspectionOrientationVector = inspectionOrientation(
                    for: ufo,
                    camera: camera,
                    restOrientation: restOrientation
                ).vector

                // Billboard is deliberately transient. It marks the single camera-facing sample
                // requested by SwiftUI, then is removed before inspection continues so walking
                // around the table cannot keep rotating the UFO toward the phone.
                ufo.components.remove(BillboardComponent.self)
            }
            guard let targetVector = inspection.inspectionOrientationVector else { continue }
            let targetOrientation = simd_quatf(
                ix: targetVector.x,
                iy: targetVector.y,
                iz: targetVector.z,
                r: targetVector.w
            )

            switch inspection.phase {
            case .resting:
                break
            case .presenting:
                inspection.progress = min(
                    inspection.progress + deltaTime / UFOInspectionComponent.transitionDuration,
                    1
                )
                applyOrientation(
                    to: ufo,
                    from: restOrientation,
                    toward: targetOrientation,
                    progress: inspection.progress
                )
                if inspection.progress >= 1 {
                    inspection.phase = .inspecting
                }
            case .inspecting:
                // Hold the one-time camera-facing pose in world space while the learner moves.
                ufo.setOrientation(targetOrientation, relativeTo: nil)
            case .dismissing:
                inspection.progress = max(
                    inspection.progress - deltaTime / UFOInspectionComponent.transitionDuration,
                    0
                )
                applyOrientation(
                    to: ufo,
                    from: restOrientation,
                    toward: targetOrientation,
                    progress: inspection.progress
                )
                if inspection.progress <= 0 {
                    ufo.setOrientation(restOrientation, relativeTo: nil)
                    inspection.phase = .resting
                    inspection.restOrientationVector = nil
                    inspection.inspectionOrientationVector = nil
                    ufo.components.remove(BillboardComponent.self)
                }
            }

            ufo.components[UFOInspectionComponent.self] = inspection
        }
    }

    private func inspectionOrientation(
        for ufo: Entity,
        camera: Entity,
        restOrientation: simd_quatf
    ) -> simd_quatf {
        let offset = camera.position(relativeTo: nil) - ufo.position(relativeTo: nil)
        guard simd_length_squared(offset) > 0.000001 else { return restOrientation }

        let directionToCamera = simd_normalize(offset)
        let restBottomDirection = restOrientation.act(SIMD3<Float>(0, -1, 0))
        let bottomToCamera = simd_quatf(from: restBottomDirection, to: directionToCamera)
        return simd_normalize(bottomToCamera * restOrientation)
    }

    private func applyOrientation(
        to entity: Entity,
        from rest: simd_quatf,
        toward target: simd_quatf,
        progress: Float
    ) {
        let clamped = min(max(progress, 0), 1)
        let eased = clamped * clamped * (3 - 2 * clamped)
        entity.setOrientation(simd_slerp(rest, target, eased), relativeTo: nil)
    }
}
