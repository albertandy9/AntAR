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
        director.components[GameStateComponent.self]?.current.supportsRouteBuilding == true,
        let ufo = context.entities(
            matching: Self.ufoQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true }),
        var follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }

        if control.resetRequestID != control.handledResetRequestID {
            control.handledResetRequestID = control.resetRequestID
            control.setThrottle(0)

            if let start = follower.routeStartPosition {
                ufo.setPosition(start, relativeTo: ufo.parent)
            }
            follower.state = .idle
            follower.stallReason = nil
            follower.moveRequested = true
            follower.completionReported = false
            follower.currentTargetOrder = 1
            follower.elapsedTravelTime = 0
            follower.steeringError = 0
            follower.previousSteeringError = 0
            follower.lineLostDuration = 0
            follower.leftMotorPower = 0
            follower.rightMotorPower = 0
        }

        if control.isPedalPressed, follower.state == .idle {
            follower.moveRequested = true
        }

        // Placing the missing next block raises `moveRequested`. Rearm only the recoverable
        // no-path stall; reflected-light stalls still require an explicit reset.
        if follower.state == .stalled,
           follower.stallReason == .noPath,
           follower.moveRequested {
            follower.state = .idle
            follower.stallReason = nil
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

}
