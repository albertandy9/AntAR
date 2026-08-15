//
//  BlockPlacementGuideSystem.swift
//  AntAR
//

import RealityKit

/// Gives the active dashed placement outline a restrained pulse without rebuilding materials.
public struct BlockPlacementGuideSystem: System {
    private static let query = EntityQuery(where: .has(BlockPlacementGuideComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var guide = entity.components[BlockPlacementGuideComponent.self],
                  guide.isActive else {
                continue
            }

            guide.pulsePhase = (guide.pulsePhase + deltaTime * 1.8)
                .truncatingRemainder(dividingBy: 1)
            entity.components[BlockPlacementGuideComponent.self] = guide

            let opacity = 0.62 + (sin(guide.pulsePhase * .pi * 2) + 1) * 0.16
            if var component = entity.components[OpacityComponent.self] {
                component.opacity = opacity
                entity.components[OpacityComponent.self] = component
            } else {
                entity.components.set(OpacityComponent(opacity: opacity))
            }
        }
    }
}
