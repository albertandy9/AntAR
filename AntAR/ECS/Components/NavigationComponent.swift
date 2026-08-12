//
//  NavigationComponent.swift
//  AntAR
//
//  Runtime waypoint-following state, written by spawn/gameplay code and consumed by
//  AntNavigationSystem. Not authored in RC Pro — waypoints are computed at runtime.
//

import RealityKit

public struct NavigationComponent: Component {
    // RUNTIME ONLY - do not expose
    public var pathIndex: Int = 0
    // RUNTIME ONLY - do not expose
    public var waypoints: [SIMD3<Float>] = []

    public init() {}
}
