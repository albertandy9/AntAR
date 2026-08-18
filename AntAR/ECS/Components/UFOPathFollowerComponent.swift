//
//  UFOPathFollowerComponent.swift
//  AntAR
//

import RealityKit

public enum UFOTravelState: String, Codable, Sendable {
    case idle
    case following
    case stalled
    case arrived
}

public enum UFOStallReason: String, Codable, Sendable {
    case noPath
    case lightBlockReflectsIR
}

/// Runtime motion state for the scene-authored travel UFO.
///
/// The global `GameState` owns narrative flow. This component owns the local, repeatable machine
/// behaviour: start, follow, stall, retry, and arrive.
public struct UFOPathFollowerComponent: Component, Codable {
    public var state: UFOTravelState
    public var stallReason: UFOStallReason?
    public var sensorCount: Int
    public var moveRequested: Bool
    public var completionReported: Bool
    public var currentTargetOrder: Int
    public var elapsedTravelTime: Float
    /// Start position in the travel UFO parent's coordinate space, so AR anchor corrections do
    /// not invalidate reset behavior.
    public var routeStartPosition: SIMD3<Float>?
    public var hoverHeight: Float
    public var steeringError: Float
    public var previousSteeringError: Float
    public var lineLostDuration: Float
    public var leftMotorPower: Float
    public var rightMotorPower: Float

    public init(
        state: UFOTravelState = .idle,
        stallReason: UFOStallReason? = nil,
        sensorCount: Int = 2,
        moveRequested: Bool = false,
        completionReported: Bool = false,
        currentTargetOrder: Int = 1,
        elapsedTravelTime: Float = 0,
        routeStartPosition: SIMD3<Float>? = nil,
        hoverHeight: Float = 0.43,
        steeringError: Float = 0,
        previousSteeringError: Float = 0,
        lineLostDuration: Float = 0,
        leftMotorPower: Float = 0,
        rightMotorPower: Float = 0
    ) {
        self.state = state
        self.stallReason = stallReason
        self.sensorCount = min(max(sensorCount, IRSensorLayout.minimumCount), IRSensorLayout.maximumCount)
        self.moveRequested = moveRequested
        self.completionReported = completionReported
        self.currentTargetOrder = currentTargetOrder
        self.elapsedTravelTime = elapsedTravelTime
        self.routeStartPosition = routeStartPosition
        self.hoverHeight = max(hoverHeight, 0.05)
        self.steeringError = steeringError
        self.previousSteeringError = previousSteeringError
        self.lineLostDuration = lineLostDuration
        self.leftMotorPower = leftMotorPower
        self.rightMotorPower = rightMotorPower
    }

    public static let travelSpeed: Float = 0.20
    public static let arrivalDistance: Float = 0.08
    public static let maximumHomeConnectionDistance: Float = 0.70
    public static let proportionalGain: Float = 1.75
    public static let derivativeGain: Float = 0.035
    public static let maximumTurnRate: Float = 2.6
    public static let maximumLineLostDuration: Float = 0.75
    /// A small fixed mismatch models ordinary left/right motor manufacturing differences.
    public static let motorImbalance: Float = 0.035
}
