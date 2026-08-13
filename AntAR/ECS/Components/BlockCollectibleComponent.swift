//
//  BlockCollectibleComponent.swift
//  AntAR
//

import RealityKit

public struct BlockCollectibleComponent: Component, Codable {
    public var isInRange: Bool
    public var isCollected: Bool

    public init(isInRange: Bool = false, isCollected: Bool = false) {
        self.isInRange = isInRange
        self.isCollected = isCollected
    }
}
