//
//  SensorLearningComponent.swift
//  AntAR
//

import RealityKit

public enum SensorLearningPhase: String, Codable, Sendable {
    /// The learner may experience the coarse response of the initial two-sensor array.
    case baseline
    /// The baseline has demonstrated instability; adding sensors is recommended but optional.
    case upgradeRecommended
    /// The learner chose to add sensors after seeing the recommendation.
    case calibrated
}

/// ECS-owned progress for the state-10 sensor lesson.
///
/// This deliberately remains separate from `GameState`: it is a local machine-learning step
/// within `ufoTravelling`, not another narrative state.
public struct SensorLearningComponent: Component, Codable, Equatable {
    public var phase: SensorLearningPhase
    public var baselineDriveDuration: Float
    /// Sensor count that produced the unstable demonstration. The lesson asks the learner to
    /// improve this configuration, rather than prescribing one globally correct number.
    public var demonstratedSensorCount: Int

    public init(
        sensorCount: Int = IRSensorLayout.minimumCount,
        baselineDriveDuration: Float = 0
    ) {
        demonstratedSensorCount = Self.clampedSensorCount(sensorCount)
        self.baselineDriveDuration = max(baselineDriveDuration, 0)
        phase = .baseline
    }

    public var recommendsUpgrade: Bool {
        phase == .upgradeRecommended
    }

    public var isCalibrated: Bool {
        phase == .calibrated
    }

    public mutating func updateSensorCount(_ sensorCount: Int) {
        let count = Self.clampedSensorCount(sensorCount)

        switch phase {
        case .baseline:
            // If the learner adjusts the array before the demonstration, evaluate the array they
            // actually tested rather than the app's original default count.
            demonstratedSensorCount = count
        case .upgradeRecommended:
            if count > demonstratedSensorCount {
                phase = .calibrated
            }
        case .calibrated:
            if count <= demonstratedSensorCount {
                phase = .upgradeRecommended
            }
        }
    }

    public mutating func recommendUpgrade(sensorCount: Int) {
        demonstratedSensorCount = Self.clampedSensorCount(sensorCount)
        // Avoid an impossible recommendation when the array is already at its authored maximum.
        phase = demonstratedSensorCount < IRSensorLayout.maximumCount ? .upgradeRecommended : .calibrated
    }

    /// Long enough to show the two-sensor oscillation, but short enough to keep the lesson moving.
    public static let baselineDemonstrationDuration: Float = 2.0

    private static func clampedSensorCount(_ sensorCount: Int) -> Int {
        min(max(sensorCount, IRSensorLayout.minimumCount), IRSensorLayout.maximumCount)
    }
}
