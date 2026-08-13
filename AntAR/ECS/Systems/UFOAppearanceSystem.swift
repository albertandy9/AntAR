//
//  UFOAppearanceSystem.swift
//  AntAR
//

import RealityKit

public struct UFOAppearanceSystem: System {
    private static let ufoQuery = EntityQuery(where: .has(UFOComponent.self))

    // TUNABLE — how long the entrance grow-in takes, in seconds.
    private static let appearDuration: Float = 0.6

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.ufoQuery, updatingSystemWhen: .rendering) {
            guard var ufo = entity.components[UFOComponent.self], ufo.appearProgress < 1 else { continue }

            ufo.appearProgress = min(ufo.appearProgress + deltaTime / Self.appearDuration, 1)
            entity.components[UFOComponent.self] = ufo
            entity.scale = SIMD3<Float>(repeating: ufo.baseScale * ufo.appearProgress)
        }
    }
}
