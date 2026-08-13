//
//  BlockComponent.swift
//  AntAR
//

import RealityKit

public struct BlockComponent: Component, Codable {
    public var baseScale: Float
    public var appearProgress: Float

    public init(baseScale: Float = 1.0, appearProgress: Float = 0.0) {
        self.baseScale = baseScale
        self.appearProgress = appearProgress
    }
}
