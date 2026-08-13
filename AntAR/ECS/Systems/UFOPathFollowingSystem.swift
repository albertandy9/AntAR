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
        where: .has(UFOPathFollowerComponent.self) && .has(IRSensorArrayComponent.self)
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
        gameState == .ufoTravelling,
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
                  let sensorArray = ufo.components[IRSensorArrayComponent.self] else {
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
                ufo.components[UFOPathFollowerComponent.self] = follower
                continue
            }

            let decision = IRLineFollowingPolicy.decide(lineSignals: sensorArray.lineSignals)
            if let target = tiles.first(where: { $0.1.order == follower.currentTargetOrder }) {
                let isDetectingReflectedTile = zip(
                    sensorArray.sampledReflectance,
                    sensorArray.isSamplingTile
                ).contains { reflectance, isSamplingTile in
                    isSamplingTile && reflectance >= 0.75
                }

                // Do not stop before the learner can see the result. The UFO approaches a light
                // block, its beam turns yellow from the IR simulation, and then it stalls.
                if !target.2.isValidPath && isDetectingReflectedTile {
                    stall(&follower, reason: .lightBlockReflectsIR)
                    ufo.components[UFOPathFollowerComponent.self] = follower
                    continue
                }

                // A tile is considered valid by its authored IR component. At the start of a
                // target transition beams can briefly sample open floor; do not turn that one
                // frame into a false stop.
                driveWithSensorArray(
                    ufo,
                    follower: &follower,
                    toward: target.0.position(relativeTo: nil),
                    deltaTime: Float(context.deltaTime),
                    decision: decision,
                    throttle: control.throttle
                )

                if simd_distance(ufo.position(relativeTo: nil), target.0.position(relativeTo: nil))
                    <= UFOPathFollowerComponent.arrivalDistance {
                    if target.2.isValidPath {
                        if target.1.order == tiles.count {
                            follower.state = .arrived
                            follower.moveRequested = false
                            follower.leftMotorPower = 0
                            follower.rightMotorPower = 0
                            report(.ufoReachedHome, on: director)
                        } else {
                            follower.currentTargetOrder += 1
                        }
                    } else {
                        stall(&follower, reason: .lightBlockReflectsIR)
                    }
                }
            } else {
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
        // State 10 says the route is available; the local move request says the post-pickup
        // moment has actually occurred. The test UI supplies that request while states 1…9 are
        // intentionally absent from this focused build.
        guard follower.state == .idle, follower.moveRequested else {
            return
        }

        guard let firstTile = tiles.first, !tiles.isEmpty else {
            stall(&follower, reason: .noPath)
            return
        }

        follower.state = .following
        follower.stallReason = nil
        follower.moveRequested = false
        follower.currentTargetOrder = firstTile.1.order
        follower.elapsedTravelTime = 0
        follower.steeringError = 0
        follower.previousSteeringError = 0
        follower.lineLostDuration = 0
        follower.leftMotorPower = 0
        follower.rightMotorPower = 0

        // Keep the authored handoff position, but align the chassis with the beginning of the
        // route exactly as a physical robot is placed facing its line before its motors start.
        face(ufo, toward: firstTile.0.position(relativeTo: nil))
    }

    /// Proportional-derivative steering expressed as differential left/right motor power.
    /// The waypoint only measures route progress; it does not pull the UFO sideways. All normal
    /// steering comes from the live weighted sensor-array error.
    private func driveWithSensorArray(
        _ ufo: Entity,
        follower: inout UFOPathFollowerComponent,
        toward target: SIMD3<Float>,
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
            let position = ufo.position(relativeTo: nil)
            let targetYaw = atan2(target.x - position.x, target.z - position.z)
            // A physical controller turns toward the last known side of the line. The authored
            // waypoint supplies a safe search direction if every sensor temporarily reads white.
            steering = clamp(shortestAngle(from: currentYaw, to: targetYaw), -0.75, 0.75)

            if follower.lineLostDuration >= UFOPathFollowerComponent.maximumLineLostDuration {
                stall(&follower, reason: .noPath)
                return
            }
        }

        let availablePower = min(max(throttle, 0), 1)
        let basePower: Float = (decision.hasLine ? 0.70 + decision.confidence * 0.20 : 0.32)
            * availablePower
        follower.leftMotorPower = clamp(basePower + steering * 0.48, 0, 1)
        follower.rightMotorPower = clamp(basePower - steering * 0.48, 0, 1)

        // For a differential drive, opposite wheel speeds create yaw. Negative sensor error
        // means the line is left, so the right motor runs faster and the robot turns left.
        let yaw = currentYaw + steering * UFOPathFollowerComponent.maximumTurnRate * deltaTime
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

    private func shortestAngle(from current: Float, to target: Float) -> Float {
        atan2(sin(target - current), cos(target - current))
    }

    private func clamp(_ value: Float, _ minimum: Float, _ maximum: Float) -> Float {
        min(max(value, minimum), maximum)
    }

    private func stall(_ follower: inout UFOPathFollowerComponent, reason: UFOStallReason) {
        follower.state = .stalled
        follower.stallReason = reason
        follower.moveRequested = false
    }

    private func report(_ event: GameEvent, on director: Entity) {
        guard var events = director.components[GameEventComponent.self] else { return }
        events.enqueue(event)
        director.components[GameEventComponent.self] = events
    }
}
