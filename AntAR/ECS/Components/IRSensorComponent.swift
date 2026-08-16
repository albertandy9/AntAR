//
//  IRSensorComponent.swift
//  AntAR
//

import RealityKit

/// A downward-facing sensor child on the UFO. Its child entity is also the IR beam visual.
public struct IRSensorComponent: Component, Codable, Equatable {
    public var index: Int
    public var lateralOffset: Float
    public var range: Float
    public var lineSignal: Float
    /// Normalized animation time for the educational IR wavefront visualization.
    public var wavePhase: Float

    public init(
        index: Int,
        lateralOffset: Float,
        range: Float,
        lineSignal: Float = 0,
        wavePhase: Float = 0
    ) {
        self.index = index
        self.lateralOffset = lateralOffset
        self.range = range
        self.lineSignal = min(max(lineSignal, 0), 1)
        self.wavePhase = wavePhase - floor(wavePhase)
    }
}

/// Sensor layout is presentation-independent and can be unit-tested without RealityKit.
public enum IRSensorLayout {
    public static let minimumCount = 2
    public static let maximumCount = 8
    public static let forwardOffset: Float = 0.085

    public static func lateralOffsets(for sensorCount: Int) -> [Float] {
        let count = min(max(sensorCount, minimumCount), maximumCount)
        let halfSpan: Float = 0.035 + Float(count - minimumCount) * 0.01
        let divisor = Float(max(count - 1, 1))

        return (0..<count).map { index in
            -halfSpan + Float(index) / divisor * halfSpan * 2
        }
    }
}
