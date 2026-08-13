//
//  BlockProximitySystem.swift
//  AntAR
//

import RealityKit

public struct BlockProximitySystem: System {
    private static let cameraQuery = EntityQuery(where: .has(PlayerCameraComponent.self))
    private static let blockQuery = EntityQuery(where: .has(BlockCollectibleComponent.self))

    private static let collectRadius: Float = 1.5

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        var cameraEntity: Entity?
        for entity in context.entities(matching: Self.cameraQuery, updatingSystemWhen: .rendering) {
            cameraEntity = entity
            break
        }
        guard let cameraEntity, cameraEntity.isAnchored else { return }
        let cameraPosition = cameraEntity.position(relativeTo: nil)

        for block in context.entities(matching: Self.blockQuery, updatingSystemWhen: .rendering) {
            guard var collectible = block.components[BlockCollectibleComponent.self], !collectible.isCollected else { continue }

            let distance = simd_distance(cameraPosition, block.position(relativeTo: nil))
            let inRange = distance <= Self.collectRadius
            if collectible.isInRange != inRange {
                collectible.isInRange = inRange
                block.components[BlockCollectibleComponent.self] = collectible
            }
        }
    }
}
