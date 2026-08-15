//
//  BlockPlacementGuideFactory.swift
//  AntAR
//

import RealityKit
import UIKit

/// Builds one reusable dashed outline around the authored `finish_block_*` positions. The solid
/// RCP marker meshes stay hidden; only this lightweight runtime guide is rendered.
@MainActor
enum BlockPlacementGuideFactory {
    private static let guideName = "RuntimeBlockPlacementGuide"
    private static let dashMesh = MeshResource.generateBox(
        size: SIMD3<Float>(repeating: 1)
    )
    private static let dashMaterial: UnlitMaterial = {
        var material = UnlitMaterial(color: UIColor(red: 1, green: 0.82, blue: 0.04, alpha: 1))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }()

    static func install(in scene: Entity) {
        guard scene.findEntity(named: guideName) == nil,
              let firstSlotName = BlockPlacementConfig.dropSlotNames.first,
              let firstSlot = scene.findEntity(named: firstSlotName),
              let parent = firstSlot.parent else {
            return
        }

        let guide = Entity()
        guide.name = guideName
        guide.components.set(BlockPlacementGuideComponent())
        guide.components.set(OpacityComponent(opacity: 0.78))
        parent.addChild(guide)

        configureOutline(on: guide, around: firstSlot, relativeTo: parent)
        guide.isEnabled = false
    }

    static func showOnlySlot(_ slotIndex: Int?, in scene: Entity) {
        install(in: scene)
        guard let guide = scene.findEntity(named: guideName) else { return }

        for slotName in BlockPlacementConfig.dropSlotNames {
            scene.findEntity(named: slotName)?.isEnabled = false
        }

        guard let slotIndex,
              BlockPlacementConfig.dropSlotNames.indices.contains(slotIndex),
              let slot = scene.findEntity(
                named: BlockPlacementConfig.dropSlotNames[slotIndex]
              ),
              let parent = slot.parent else {
            guide.isEnabled = false
            if var component = guide.components[BlockPlacementGuideComponent.self] {
                component.isActive = false
                guide.components[BlockPlacementGuideComponent.self] = component
            }
            return
        }

        if guide.parent != parent {
            guide.removeFromParent()
            parent.addChild(guide)
        }

        position(guide, around: slot, relativeTo: parent)
        guide.isEnabled = true

        var component = guide.components[BlockPlacementGuideComponent.self]
            ?? BlockPlacementGuideComponent()
        component.slotIndex = slotIndex
        component.isActive = true
        guide.components[BlockPlacementGuideComponent.self] = component
    }

    private static func configureOutline(
        on guide: Entity,
        around slot: Entity,
        relativeTo parent: Entity
    ) {
        let bounds = slot.visualBounds(relativeTo: parent)
        let extents = bounds.max - bounds.min
        let width = max(extents.x, 0.06)
        let depth = max(extents.z, 0.10)
        let halfWidth = width * 0.5
        let halfDepth = depth * 0.5

        addDashedEdge(to: guide, length: width, alongX: true, fixedOffset: -halfDepth)
        addDashedEdge(to: guide, length: width, alongX: true, fixedOffset: halfDepth)
        addDashedEdge(to: guide, length: depth, alongX: false, fixedOffset: -halfWidth)
        addDashedEdge(to: guide, length: depth, alongX: false, fixedOffset: halfWidth)
        position(guide, around: slot, relativeTo: parent)
    }

    private static func position(
        _ guide: Entity,
        around slot: Entity,
        relativeTo parent: Entity
    ) {
        let bounds = slot.visualBounds(relativeTo: parent)
        let center = (bounds.min + bounds.max) * 0.5
        guide.position = SIMD3<Float>(center.x, bounds.max.y + 0.004, center.z)
    }

    private static func addDashedEdge(
        to guide: Entity,
        length: Float,
        alongX: Bool,
        fixedOffset: Float
    ) {
        let preferredDashLength: Float = 0.024
        let preferredGap: Float = 0.014
        let count = max(2, Int(ceil(length / (preferredDashLength + preferredGap))))
        let dashLength = min(preferredDashLength, length / Float(count) * 0.72)
        let travel = max(length - dashLength, 0)

        for index in 0..<count {
            let progress = count == 1 ? 0.5 : Float(index) / Float(count - 1)
            let movingOffset = -travel * 0.5 + travel * progress
            let dash = ModelEntity(mesh: dashMesh, materials: [dashMaterial])
            dash.name = "GuideDash"

            if alongX {
                dash.position = SIMD3<Float>(movingOffset, 0, fixedOffset)
                dash.scale = SIMD3<Float>(dashLength, 0.002, 0.006)
            } else {
                dash.position = SIMD3<Float>(fixedOffset, 0, movingOffset)
                dash.scale = SIMD3<Float>(0.006, 0.002, dashLength)
            }
            guide.addChild(dash)
        }
    }
}
