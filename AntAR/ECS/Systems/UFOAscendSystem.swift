//
//  UFOAscendSystem.swift
//  AntAR
//

import RealityKit

public struct UFOAscendSystem: System {
    private static let ascendQuery = EntityQuery(where: .has(UFOAscendComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.ascendQuery, updatingSystemWhen: .rendering) {
            guard var ascend = entity.components[UFOAscendComponent.self], ascend.progress < 1 else { continue }

            ascend.progress = min(ascend.progress + deltaTime / UFOAscendComponent.duration, 1)
            entity.components[UFOAscendComponent.self] = ascend

            let eased = Self.smoothstep(ascend.progress)
            entity.setPosition(simd_mix(ascend.startPosition, ascend.targetPosition, SIMD3(repeating: eased)), relativeTo: nil)

            if var opacity = entity.components[OpacityComponent.self] {
                opacity.opacity = 1 - eased
                entity.components[OpacityComponent.self] = opacity
            }

            if ascend.progress >= 1 {
                entity.isEnabled = false
            }
        }
    }

    private static func smoothstep(_ t: Float) -> Float {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
