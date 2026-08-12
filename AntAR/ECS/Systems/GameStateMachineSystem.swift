//
//  GameStateMachineSystem.swift
//  AntAR
//

import Foundation
import RealityKit

/// The sole writer of `GameStateComponent.current`.
public struct GameStateMachineSystem: System {
    private static let directorQuery = EntityQuery(
        where: .has(GameDirectorComponent.self)
            && .has(GameEventComponent.self)
            && .has(GameStateComponent.self)
    )

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for director in context.entities(matching: Self.directorQuery, updatingSystemWhen: .rendering) {
            guard var state = director.components[GameStateComponent.self],
                  var events = director.components[GameEventComponent.self] else {
                continue
            }

            state.advanceTime(by: context.deltaTime)

            if let event = events.nextEvent {
                events.consumeNextEvent()

                if let nextState = state.current.transition(for: event) {
                    state.transition(to: nextState)
                    postStateChange(from: state.previous, to: nextState, event: event, director: director)
                }
            }

            director.components[GameStateComponent.self] = state
            director.components[GameEventComponent.self] = events
        }
    }

    private func postStateChange(
        from previousState: GameState?,
        to nextState: GameState,
        event: GameEvent,
        director: Entity
    ) {
        NotificationCenter.default.post(
            name: .gameStateDidChange,
            object: director,
            userInfo: [
                GameStateNotificationKey.previous: previousState?.rawValue as Any,
                GameStateNotificationKey.current: nextState.rawValue,
                GameStateNotificationKey.event: event.rawValue
            ]
        )
    }
}
