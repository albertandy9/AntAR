//
//  HapticCueComponent.swift
//  AntAR
//

import RealityKit


public enum HapticStyle: String, Codable, Sendable {
    case light, medium, heavy, soft, rigid
}


public struct HapticCueComponent: Component, Codable {
    public var style: HapticStyle
    public var intensity: Float
    public var hasFired: Bool

    public init(style: HapticStyle = .medium, intensity: Float = 1.0, hasFired: Bool = false) {
        self.style = style
        self.intensity = intensity
        self.hasFired = hasFired
    }
}
