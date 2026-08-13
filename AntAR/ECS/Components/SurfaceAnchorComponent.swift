//
//  SurfaceAnchorComponent.swift
//  AntAR
//

import RealityKit

public struct SurfaceAnchorComponent: Component, Codable {
    public var isLocked: Bool

    public init(isLocked: Bool = false) {
        self.isLocked = isLocked
    }
}
