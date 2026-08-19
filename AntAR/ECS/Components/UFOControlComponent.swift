//
//  UFOControlComponent.swift
//  AntAR
//

import RealityKit

/// Player intent for the state-10 UFO, stored on the `GameDirector` entity.
///
/// SwiftUI writes only this component. RealityKit systems remain the sole owners of movement,
/// follower state, and transform resets.
public struct UFOControlComponent: Component, Codable {
    /// Normalized pedal pressure. The current press-and-hold UI writes either `0` or `1`, while
    /// keeping this analog allows a future pressure-sensitive control without changing systems.
    public var throttle: Float
    public var resetRequestID: UInt64
    public var handledResetRequestID: UInt64
    /// Incremented when the authored route changes while the UFO is travelling. Unlike reset,
    /// this asks the movement system to sample the route again without changing the UFO transform
    /// or its current target.
    public var routeChangeRequestID: UInt64
    public var handledRouteChangeRequestID: UInt64

    public init(
        throttle: Float = 0,
        resetRequestID: UInt64 = 0,
        handledResetRequestID: UInt64 = 0,
        routeChangeRequestID: UInt64 = 0,
        handledRouteChangeRequestID: UInt64 = 0
    ) {
        self.throttle = min(max(throttle, 0), 1)
        self.resetRequestID = resetRequestID
        self.handledResetRequestID = handledResetRequestID
        self.routeChangeRequestID = routeChangeRequestID
        self.handledRouteChangeRequestID = handledRouteChangeRequestID
    }

    public var isPedalPressed: Bool {
        throttle > 0.01
    }

    public mutating func setThrottle(_ value: Float) {
        throttle = min(max(value, 0), 1)
    }

    public mutating func requestReset() {
        resetRequestID &+= 1
        throttle = 0
    }

    public mutating func requestRouteReevaluation() {
        routeChangeRequestID &+= 1
        throttle = 0
    }
}
