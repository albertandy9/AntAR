//
//  IRLineFollowingPolicy.swift
//  AntAR
//

import Foundation

/// Pure, testable decision rule for the current sensor strip.
public struct IRLineFollowingDecision: Equatable, Sendable {
    public var lateralCorrection: Float
    public var hasLine: Bool
    public var confidence: Float

    public init(lateralCorrection: Float, hasLine: Bool, confidence: Float) {
        self.lateralCorrection = lateralCorrection
        self.hasLine = hasLine
        self.confidence = confidence
    }
}

public enum IRLineFollowingPolicy {
    /// `lineSignals` are dark-line activations (not reflected intensity): 0 means bare/light
    /// surface; 1 means dark/absorbing path. Negative correction means steer left.
    public static func decide(lineSignals: [Float]) -> IRLineFollowingDecision {
        guard !lineSignals.isEmpty else {
            return IRLineFollowingDecision(lateralCorrection: 0, hasLine: false, confidence: 0)
        }

        let totalSignal = lineSignals.reduce(0, +)
        guard totalSignal > 0.05 else {
            return IRLineFollowingDecision(lateralCorrection: 0, hasLine: false, confidence: 0)
        }

        let weightedSignal = lineSignals.enumerated().reduce(Float.zero) { result, item in
            let normalizedOffset: Float
            if lineSignals.count == 1 {
                normalizedOffset = 0
            } else {
                normalizedOffset = Float(item.offset) / Float(lineSignals.count - 1) * 2 - 1
            }
            return result + normalizedOffset * item.element
        }

        return IRLineFollowingDecision(
            lateralCorrection: weightedSignal / totalSignal,
            hasLine: true,
            confidence: min(max(lineSignals.max() ?? 0, 0), 1)
        )
    }

    public static let digitalThreshold: Float = 0.50
}
