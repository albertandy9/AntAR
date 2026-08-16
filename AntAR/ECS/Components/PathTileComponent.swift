//
//  PathTileComponent.swift
//  AntAR
//

import RealityKit

public struct PathTileComponent: Component, Codable {
    public var order: Int
    public var isPlaced: Bool

    public init(order: Int, isPlaced: Bool = false) {
        self.order = order
        self.isPlaced = isPlaced
    }
}
