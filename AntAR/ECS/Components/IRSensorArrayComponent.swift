//
//  IRSensorArrayComponent.swift
//  AntAR
//

import RealityKit

/// Aggregated current sensor values on the UFO, ordered left to right.
public struct IRSensorArrayComponent: Component, Codable {
    public var lineSignals: [Float]
    public var sampledReflectance: [Float]
    public var isSamplingTile: [Bool]
    public var visualUpdateAccumulator: Float
    /// Shared deterministic clock for repeatable sensor variation; never uses frame-random values.
    public var simulationTime: Float

    public init(sensorCount: Int = 2) {
        let count = min(max(sensorCount, IRSensorLayout.minimumCount), IRSensorLayout.maximumCount)
        lineSignals = Array(repeating: 0, count: count)
        sampledReflectance = Array(repeating: 1, count: count)
        isSamplingTile = Array(repeating: false, count: count)
        visualUpdateAccumulator = 0
        simulationTime = 0
    }
}
