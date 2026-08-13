//
//  PathTileComponent.swift
//  AntAR
//

import RealityKit

/// Runtime data for one of the four reusable, scene-authored route tiles.
public struct PathTileComponent: Component, Codable {
    public var order: Int
    public var isPlaced: Bool

    public init(order: Int, isPlaced: Bool = false) {
        self.order = order
        self.isPlaced = isPlaced
    }
}
