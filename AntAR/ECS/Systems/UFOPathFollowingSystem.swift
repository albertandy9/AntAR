//
//  UFOPathFollowingSystem.swift
//  AntAR
//

import RealityKit
import simd

/// Moves the scene-authored UFO across the ordered, placed route tiles.
///
/// A light/reflection tile stops the UFO before movement; a dark/absorption tile contributes a
/// positive line signal. On reaching the authored ant nest the system reports `ufoReachedHome`
/// instead of mutating the global state itself.
public struct UFOPathFollowingSystem: System {
    /// RealityKit can expose a newly attached component to an EntityQuery one render update after
    /// the placement callback. Avoid turning that synchronization frame into a permanent no-path
    /// stall before the placed tile becomes queryable.
    private static let placedTileQueryGraceDuration: Float = 0.20

    public static let dependencies: [SystemDependency] = [
        .after(IRSimulationSystem.self),
        .after(UFOControlSystem.self)
    ]

    private static let directorQuery = EntityQuery(
        where: .has(GameEventComponent.self)
            && .has(GameStateComponent.self)
            && .has(UFOControlComponent.self)
    )
    private static let ufoQuery = EntityQuery(
        where: .has(UFOPathFollowerComponent.self)
            && .has(IRSensorArrayComponent.self)
            && .has(SensorLearningComponent.self)
    )
    private static let tileQuery = EntityQuery(
        where: .has(PathTileComponent.self) && .has(IRReflectanceComponent.self)
    )
    private static let homeQuery = EntityQuery(where: .has(HomeComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        guard let director = context.entities(
            matching: Self.directorQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true }),
        let gameState = director.components[GameStateComponent.self]?.current,
        let control = director.components[UFOControlComponent.self],
        gameState.supportsRouteBuilding,
        context.entities(
            matching: Self.homeQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true }) != nil else {
            return
        }

        let tiles = context.entities(
            matching: Self.tileQuery,
            updatingSystemWhen: .rendering
        ).compactMap { entity -> (Entity, PathTileComponent, IRReflectanceComponent)? in
            guard let tile = entity.components[PathTileComponent.self],
                  let reflectance = entity.components[IRReflectanceComponent.self],
                  tile.isPlaced else {
                return nil
            }
            return (entity, tile, reflectance)
        }
        .sorted { $0.1.order < $1.1.order }

        for ufo in context.entities(matching: Self.ufoQuery, updatingSystemWhen: .rendering) {
            guard var follower = ufo.components[UFOPathFollowerComponent.self],
                  let sensorArray = ufo.components[IRSensorArrayComponent.self],
                  var learning = ufo.components[SensorLearningComponent.self] else {
                continue
            }

            let learningBeforeSensorCheck = learning
            learning.updateSensorCount(follower.sensorCount)
            if learning != learningBeforeSensorCheck {
                ufo.components[SensorLearningComponent.self] = learning
            }

            // Inspection owns the chassis orientation and intentionally pauses both motors.
            if ufo.components[UFOInspectionComponent.self]?.isActive == true {
                follower.leftMotorPower = 0
                follower.rightMotorPower = 0
                ufo.components[UFOPathFollowerComponent.self] = follower
                continue
            }

            // The UFO may reach the fifth block before the story state machine has consumed the
            // collection/placement events. Remember arrival locally, then publish completion once
            // the canonical state reaches `.ufoTravelling`.
            if follower.state == .arrived {
                if gameState == .ufoTravelling, !follower.completionReported {
                    report(.ufoReachedHome, on: director)
                    follower.completionReported = true
                }
                follower.leftMotorPower = 0
                follower.rightMotorPower = 0
                ufo.components[UFOPathFollowerComponent.self] = follower
                continue
            }

            // Repair a transient no-path classification if a newly placed light block entered
            // the ECS query on the following frame. This runs even after the control system has
            // released throttle, so the user receives the correct explanation without retrying.
            if follower.state == .stalled,
               follower.stallReason == .noPath,
               let delayedTarget = tiles.first(where: {
                   $0.1.order == follower.currentTargetOrder
               }),
               !delayedTarget.2.isValidPath {
                follower.stallReason = .lightBlockReflectsIR
                ufo.components[UFOPathFollowerComponent.self] = follower
                continue
            }

            guard control.isPedalPressed else {
                follower.leftMotorPower = 0
                follower.rightMotorPower = 0
                ufo.components[UFOPathFollowerComponent.self] = follower
                continue
            }

            beginRunIfNeeded(
                follower: &follower,
                ufo: ufo,
                tiles: tiles
            )

            guard follower.state == .following else {
                if follower.state == .idle, follower.moveRequested {
                    follower.lineLostDuration += Float(context.deltaTime)
                    if follower.lineLostDuration >= Self.placedTileQueryGraceDuration {
                        stall(&follower, reason: .noPath)
                    }
                }
                ufo.components[UFOPathFollowerComponent.self] = follower
                continue
            }

            let decision = IRLineFollowingPolicy.decide(lineSignals: sensorArray.lineSignals)
            if let target = tiles.first(where: { $0.1.order == follower.currentTargetOrder }) {
                // The ordered tile list already proves that a block exists in the next slot.
                // Classify its authored IR material before applying the no-signal timeout;
                // otherwise the short gap before the sensors physically overlap a bright block
                // is incorrectly reported as an empty route.
                if !target.2.isValidPath {
                    stall(&follower, reason: .lightBlockReflectsIR)
                    ufo.components[UFOPathFollowerComponent.self] = follower
                    continue
                }

                if learning.phase == .baseline {
                    learning.baselineDriveDuration += Float(context.deltaTime)
                    if learning.baselineDriveDuration
                        >= SensorLearningComponent.baselineDemonstrationDuration {
                        learning.recommendUpgrade(sensorCount: follower.sensorCount)
                        ufo.components[SensorLearningComponent.self] = learning
                    }
                    ufo.components[SensorLearningComponent.self] = learning
                }

                // A tile is considered valid by its authored IR component. At the start of a
                // target transition beams can briefly sample open floor; do not turn that one
                // frame into a false stop.
                driveWithSensorArray(
                    ufo,
                    follower: &follower,
                    deltaTime: Float(context.deltaTime),
                    decision: decision,
                    throttle: control.throttle
                )

                if simd_distance(ufo.position(relativeTo: nil), target.0.position(relativeTo: nil))
                    <= UFOPathFollowerComponent.arrivalDistance {
                    if target.1.order >= BlockPlacementConfig.requiredPathBlockCount {
                        follower.state = .arrived
                        follower.moveRequested = false
                        follower.leftMotorPower = 0
                        follower.rightMotorPower = 0
                        if gameState == .ufoTravelling, !follower.completionReported {
                            report(.ufoReachedHome, on: director)
                            follower.completionReported = true
                        }
                    } else if tiles.contains(where: { $0.1.order == target.1.order + 1 }) {
                        follower.currentTargetOrder += 1
                    } else {
                        waitForNextTile(&follower, after: target.1.order)
                    }
                }
            } else {
                // Never let waypoint steering pull the UFO into empty space. Missing the next
                // placed order is an explicit, recoverable no-path stall surfaced by the UI.
                stall(&follower, reason: .noPath)
            }

            ufo.components[UFOPathFollowerComponent.self] = follower
        }
    }

    private func beginRunIfNeeded(
        follower: inout UFOPathFollowerComponent,
        ufo: Entity,
        tiles: [(Entity, PathTileComponent, IRReflectanceComponent)]
    ) {
        // A placement requests movement immediately. `currentTargetOrder` remembers where an
        // incremental route stopped, so adding block 2 continues from block 1 instead of sending
        // the UFO back to the beginning.
        let canStart = follower.state == .idle
            || (follower.state == .stalled && follower.stallReason == .noPath)
        guard canStart, follower.moveRequested else {
            return
        }

        guard let nextTile = tiles.first(where: {
            $0.1.order == follower.currentTargetOrder
        }) else {
            // Keep the request alive briefly. A genuinely empty slot becomes `.noPath` in
            // `update`, while a tile placed this frame can enter the query on the next update.
            return
        }

        let isInitialLaunch = follower.currentTargetOrder == 1
            && follower.elapsedTravelTime <= 0.0001

        follower.state = .following
        follower.stallReason = nil
        follower.moveRequested = false
        follower.steeringError = 0
        follower.previousSteeringError = 0
        follower.lineLostDuration = 0
        follower.leftMotorPower = 0
        follower.rightMotorPower = 0

        // Align only when the UFO first enters the route. Re-aiming at a newly placed tile after
        // a no-path stall can point backward when the chassis has already crossed the previous
        // tile's centre. Incremental continuation must preserve the heading at which it stopped.
        if isInitialLaunch {
            face(ufo, toward: nextTile.0.position(relativeTo: nil))
        }
    }

    /// Proportional-derivative steering expressed as differential left/right motor power.
    /// The waypoint only measures route progress; it never pulls the UFO through empty space.
    /// All steering comes from the live weighted sensor-array error.
    private func driveWithSensorArray(
        _ ufo: Entity,
        follower: inout UFOPathFollowerComponent,
        deltaTime: Float,
        decision: IRLineFollowingDecision,
        throttle: Float
    ) {
        guard deltaTime > 0 else { return }

        let orientation = ufo.orientation(relativeTo: nil)
        let currentForward = orientation.act(SIMD3<Float>(0, 0, 1))
        let currentYaw = atan2(currentForward.x, currentForward.z)

        let steering: Float
        if decision.hasLine {
            follower.lineLostDuration = 0
            follower.previousSteeringError = follower.steeringError
            follower.steeringError = decision.lateralCorrection

            let derivative = (follower.steeringError - follower.previousSteeringError) / deltaTime
            steering = clamp(
                follower.steeringError * UFOPathFollowerComponent.proportionalGain
                    + derivative * UFOPathFollowerComponent.derivativeGain,
                -1,
                1
            )
        } else {
            follower.lineLostDuration += deltaTime
            follower.leftMotorPower = 0
            follower.rightMotorPower = 0

            if follower.lineLostDuration >= UFOPathFollowerComponent.maximumLineLostDuration {
                stall(&follower, reason: .noPath)
            }
            // A physical line follower cannot safely infer a forward route when every sensor is
            // over empty space. Pause in place during the short debounce window, then stall.
            return
        }

        let availablePower = min(max(throttle, 0), 1)
        let basePower: Float = (decision.hasLine ? 0.70 + decision.confidence * 0.20 : 0.32)
            * availablePower
        let imbalance = UFOPathFollowerComponent.motorImbalance
        follower.leftMotorPower = clamp(
            basePower * (1 + imbalance) + steering * 0.48,
            0,
            1
        )
        follower.rightMotorPower = clamp(
            basePower * (1 - imbalance) - steering * 0.48,
            0,
            1
        )

        // Derive yaw from the actual wheel powers so the fixed motor mismatch creates a genuine
        // drift that the sensor array has to measure and correct. More spatial samples detect the
        // edge sooner and turn this coarse two-sensor oscillation into a smooth correction.
        let motorTurn = clamp(
            (follower.leftMotorPower - follower.rightMotorPower) / 0.96,
            -1,
            1
        )
        let yaw = currentYaw + motorTurn * UFOPathFollowerComponent.maximumTurnRate * deltaTime
        let forward = SIMD3<Float>(sin(yaw), 0, cos(yaw))
        let averagePower = (follower.leftMotorPower + follower.rightMotorPower) / 2

        var position = ufo.position(relativeTo: nil)
        position += forward * UFOPathFollowerComponent.travelSpeed * averagePower * deltaTime
        ufo.setPosition(position, relativeTo: nil)
        ufo.setOrientation(
            simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0)),
            relativeTo: nil
        )
        follower.elapsedTravelTime += deltaTime
    }

    private func face(_ entity: Entity, toward target: SIMD3<Float>) {
        let position = entity.position(relativeTo: nil)
        let offset = target - position
        guard simd_length_squared(SIMD2(offset.x, offset.z)) > 0.000001 else { return }
        let yaw = atan2(offset.x, offset.z)
        entity.setOrientation(
            simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0)),
            relativeTo: nil
        )
    }

    private func clamp(_ value: Float, _ minimum: Float, _ maximum: Float) -> Float {
        min(max(value, minimum), maximum)
    }

    private func stall(_ follower: inout UFOPathFollowerComponent, reason: UFOStallReason) {
        follower.state = .stalled
        follower.stallReason = reason
        follower.moveRequested = false
        follower.leftMotorPower = 0
        follower.rightMotorPower = 0
    }

    private func waitForNextTile(_ follower: inout UFOPathFollowerComponent, after order: Int) {
        follower.currentTargetOrder = order + 1
        stall(&follower, reason: .noPath)
    }

    private func report(_ event: GameEvent, on director: Entity) {
        guard var events = director.components[GameEventComponent.self] else { return }
        events.enqueue(event)
        director.components[GameEventComponent.self] = events
    }
}
