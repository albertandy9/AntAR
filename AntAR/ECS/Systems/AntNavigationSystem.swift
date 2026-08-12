//
//  AntNavigationSystem.swift
//  AntAR
//
import RealityKit
import Foundation

public struct AntNavigationSystem: System {
    private static let movementQuery = EntityQuery(where: .has(AntBehaviorComponent.self) && .has(NavigationComponent.self))

    // TUNABLE — distance (meters) under which a waypoint counts as "reached".
    private static let arrivalThreshold: Float = 0.02
    // TUNABLE — how long an antenna ant takes to fade out, starting once it passes its first
    // waypoint (table center). Combined with its speed, this determines how far it travels
    // before it's gone: distance ≈ speed × fadeOutDuration.
    private static let fadeOutDuration: Float = 2.0

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        updateMovement(context: context)
    }

    private func updateMovement(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.movementQuery, updatingSystemWhen: .rendering) {
            guard let behavior = entity.components[AntBehaviorComponent.self],
                  var navigation = entity.components[NavigationComponent.self],
                  behavior.state == .walk else { continue }

            // BUG FIXED: fading used to only start once the path was fully exhausted, meaning
            // the ant stopped dead at its last waypoint and THEN faded in place — visually a
            // second "stopped" ant right up until it vanished. Antenna ants now start fading as
            // soon as they pass their first waypoint (table center) while STILL walking toward
            // the next one, so movement and fading happen at the same time and it never actually
            // stops before disappearing.
            if behavior.hasAntenna && navigation.pathIndex >= 1 {
                if fadeOutAndCheckRemoved(entity: entity, deltaTime: deltaTime) {
                    continue
                }
            }

            guard navigation.pathIndex < navigation.waypoints.count else { continue }

            let target = navigation.waypoints[navigation.pathIndex]
            let current = entity.position(relativeTo: nil)
            let offset = target - current
            let distance = simd_length(offset)

            if distance <= Self.arrivalThreshold {
                navigation.pathIndex += 1
                entity.components[NavigationComponent.self] = navigation

                if navigation.pathIndex >= navigation.waypoints.count && !behavior.hasAntenna {
                    NotificationCenter.default.post(
                        name: .antReached,
                        object: nil,
                        userInfo: ["entityID": entity.id, "entityName": entity.name]
                    )
                }
                continue
            }

            let step = min(behavior.speed * deltaTime, distance)
            let direction = offset / distance
            entity.setPosition(current + direction * step, relativeTo: nil)
        }
    }

    /// Returns true if the entity was fully faded out and removed this frame.
    private func fadeOutAndCheckRemoved(entity: Entity, deltaTime: Float) -> Bool {
        guard var opacity = entity.components[OpacityComponent.self] else { return false }
        opacity.opacity -= deltaTime / Self.fadeOutDuration
        if opacity.opacity <= 0 {
            entity.removeFromParent()
            return true
        }
        entity.components[OpacityComponent.self] = opacity
        return false
    }
}
