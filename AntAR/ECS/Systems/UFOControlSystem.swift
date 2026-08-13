//
//  UFOControlSystem.swift
//  AntAR
//

import RealityKit
import simd

/// Consumes gas and reset intent from `UFOControlComponent`.
///
/// This is the only reset authority for the travel UFO. UI code never changes the follower or
/// entity transform directly, which keeps replay behavior deterministic and ECS-owned.
public struct UFOControlSystem: System {
    public static let dependencies: [SystemDependency] = [.after(SceneBindingSystem.self)]

    private static let directorQuery = EntityQuery(
        where: .has(GameDirectorComponent.self)
            && .has(GameEventComponent.self)
            && .has(GameStateComponent.self)
            && .has(UFOControlComponent.self)
    )
    private static let ufoQuery = EntityQuery(where: .has(UFOPathFollowerComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        guard let director = context.entities(
            matching: Self.directorQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true }),
        var control = director.components[UFOControlComponent.self],
        let gameState = director.components[GameStateComponent.self]?.current,
        let root = director.parent,
        let ufo = context.entities(
            matching: Self.ufoQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true }),
        var follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }

        if control.resetRequestID != control.handledResetRequestID {
            control.throttle = 0

            if gameState == .completed {
                // CompletionPresentationSystem owns the final pose while state 11 is active.
                // Request the reverse test transition first, then perform the pending reset once
                // the state machine has re-entered state 10 on the following scene update.
                enqueue(.ufoResetRequested, on: director)
            } else {
                reset(
                    ufo: ufo,
                    follower: &follower,
                    root: root
                )
                control.handledResetRequestID = control.resetRequestID
            }
        } else if control.isPedalPressed, follower.state == .idle {
            follower.moveRequested = true
        }

        // A stalled or arrived machine cannot keep consuming throttle after its control leaves
        // the screen. Reset is deliberately required before a new run from either terminal state.
        if follower.state == .stalled || follower.state == .arrived {
            control.throttle = 0
            follower.leftMotorPower = 0
            follower.rightMotorPower = 0
        }

        ufo.components[UFOPathFollowerComponent.self] = follower
        director.components[UFOControlComponent.self] = control
    }

    private func reset(
        ufo: Entity,
        follower: inout UFOPathFollowerComponent,
        root: Entity
    ) {
        if let start = follower.routeStartPosition {
            ufo.setPosition(start, relativeTo: nil)
        }

        if let firstTile = root.antarDescendant(named: AntARSceneNames.pathTiles[0]) {
            face(ufo, toward: firstTile.position(relativeTo: nil))
        }

        follower.state = .idle
        follower.stallReason = nil
        follower.moveRequested = true
        follower.currentTargetOrder = 1
        follower.elapsedTravelTime = 0
        follower.steeringError = 0
        follower.previousSteeringError = 0
        follower.lineLostDuration = 0
        follower.leftMotorPower = 0
        follower.rightMotorPower = 0

        if var sensors = ufo.components[IRSensorArrayComponent.self] {
            sensors.lineSignals = Array(repeating: 0, count: follower.sensorCount)
            sensors.sampledReflectance = Array(repeating: 1, count: follower.sensorCount)
            sensors.isSamplingTile = Array(repeating: false, count: follower.sensorCount)
            ufo.components[IRSensorArrayComponent.self] = sensors
        }
    }

    private func face(_ entity: Entity, toward target: SIMD3<Float>) {
        let position = entity.position(relativeTo: nil)
        let offset = target - position
        guard simd_length_squared(SIMD2(offset.x, offset.z)) > 0.000001 else { return }

        entity.setOrientation(
            simd_quatf(
                angle: atan2(offset.x, offset.z),
                axis: SIMD3<Float>(0, 1, 0)
            ),
            relativeTo: nil
        )
    }

    private func enqueue(_ event: GameEvent, on director: Entity) {
        guard var events = director.components[GameEventComponent.self] else { return }
        events.enqueue(event)
        director.components[GameEventComponent.self] = events
    }
}
