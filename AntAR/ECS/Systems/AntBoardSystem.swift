//
//  AntBoardSystem.swift
//  AntAR
//

import RealityKit

public struct AntBoardSystem: System {
    private static let boardQuery = EntityQuery(where: .has(AntBoardComponent.self))
    private static let directorQuery = EntityQuery(
        where: .has(GameDirectorComponent.self) && .has(GameEventComponent.self)
    )

    // TUNABLE — how long the rise-and-fade takes, in seconds. Was 1.2 (felt too quick).
    private static let boardDuration: Float = 2.5

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        var didFinishBoarding = false

        for entity in context.entities(matching: Self.boardQuery, updatingSystemWhen: .rendering) {
            guard var board = entity.components[AntBoardComponent.self], board.progress < 1 else { continue }

            board.progress = min(board.progress + deltaTime / Self.boardDuration, 1)
            entity.components[AntBoardComponent.self] = board

            let eased = Self.smoothstep(board.progress)
            entity.setPosition(simd_mix(board.startPosition, board.targetPosition, SIMD3(repeating: eased)), relativeTo: nil)

            if var opacity = entity.components[OpacityComponent.self] {
                opacity.opacity = 1 - eased
                entity.components[OpacityComponent.self] = opacity
            }

            if board.progress >= 1 {
                entity.isEnabled = false
                didFinishBoarding = true
            }
        }

        guard didFinishBoarding else { return }
        for director in context.entities(matching: Self.directorQuery, updatingSystemWhen: .rendering) {
            guard var events = director.components[GameEventComponent.self] else { continue }
            events.enqueue(.antBoardedUFO)
            director.components[GameEventComponent.self] = events
        }
    }

    private static func smoothstep(_ t: Float) -> Float {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
