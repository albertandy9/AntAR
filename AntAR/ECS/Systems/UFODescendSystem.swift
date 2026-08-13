//
//  UFODescendSystem.swift
//  AntAR
//

import RealityKit

public struct UFODescendSystem: System {
    private static let descendQuery = EntityQuery(where: .has(UFODescendComponent.self))
    private static let directorQuery = EntityQuery(
        where: .has(GameDirectorComponent.self) && .has(GameEventComponent.self)
    )

    // TUNABLE — how long the descend takes, in seconds.
    private static let descendDuration: Float = 1.2

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        var didArrive = false

        for entity in context.entities(matching: Self.descendQuery, updatingSystemWhen: .rendering) {
            guard var descend = entity.components[UFODescendComponent.self], descend.progress < 1 else { continue }

            descend.progress = min(descend.progress + deltaTime / Self.descendDuration, 1)
            entity.components[UFODescendComponent.self] = descend

            let eased = Self.smoothstep(descend.progress)
            entity.setPosition(simd_mix(descend.startPosition, descend.targetPosition, SIMD3(repeating: eased)), relativeTo: nil)

            if descend.progress >= 1 {
                didArrive = true
            }
        }

        guard didArrive else { return }
        for director in context.entities(matching: Self.directorQuery, updatingSystemWhen: .rendering) {
            guard var events = director.components[GameEventComponent.self] else { continue }
            events.enqueue(.ufoReachedLostAnt)
            director.components[GameEventComponent.self] = events
        }
    }

    private static func smoothstep(_ t: Float) -> Float {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
