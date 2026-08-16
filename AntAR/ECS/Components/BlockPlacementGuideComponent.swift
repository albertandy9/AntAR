//
//  BlockPlacementGuideComponent.swift
//  AntAR
//

import RealityKit

/// Runtime state for the single dashed outline that points to the next empty authored slot.
public struct BlockPlacementGuideComponent: Component, Codable {
    public var slotIndex: Int
    public var pulsePhase: Float
    public var isActive: Bool

    public init(slotIndex: Int = 0, pulsePhase: Float = 0, isActive: Bool = false) {
        self.slotIndex = max(slotIndex, 0)
        self.pulsePhase = pulsePhase
        self.isActive = isActive
    }
}
