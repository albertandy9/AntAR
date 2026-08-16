//
//  BlockAppearanceSystem.swift
//  AntAR
//

import RealityKit

public struct BlockAppearanceSystem: System {
    private static let blockQuery = EntityQuery(where: .has(BlockComponent.self))

    // TUNABLE — how long the entrance grow-in takes, in seconds.
    private static let appearDuration: Float = 0.6

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.blockQuery, updatingSystemWhen: .rendering) {
            guard var block = entity.components[BlockComponent.self], block.appearProgress < 1 else { continue }

            block.appearProgress = min(block.appearProgress + deltaTime / Self.appearDuration, 1)
            entity.components[BlockComponent.self] = block
            entity.scale = block.baseScale * block.appearProgress
        }
    }
}
