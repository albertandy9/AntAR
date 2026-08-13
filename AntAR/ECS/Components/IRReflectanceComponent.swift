//
//  IRReflectanceComponent.swift
//  AntAR
//

import RealityKit

/// Optical teaching data for a route tile.
///
/// `reflectance` represents physical IR returned toward the UFO: `0` is absorption and `1` is
/// reflection. The controller uses `lineSignal = 1 - reflectance`, so dark/absorbing tiles are
/// explicitly the valid path in this project's learning model.
public struct IRReflectanceComponent: Component, Codable {
    public var reflectance: Float
    public var isValidPath: Bool

    public init(reflectance: Float, isValidPath: Bool) {
        self.reflectance = min(max(reflectance, 0), 1)
        self.isValidPath = isValidPath
    }

    public static let darkPath = IRReflectanceComponent(reflectance: 0.08, isValidPath: true)
    public static let lightObstacle = IRReflectanceComponent(reflectance: 0.92, isValidPath: false)
}

/// The two materials required by the updated PRD's route lesson.
public enum PathTileMaterial: String, CaseIterable, Codable, Sendable {
    case dark
    case light

    var irMaterial: IRReflectanceComponent {
        switch self {
        case .dark: .darkPath
        case .light: .lightObstacle
        }
    }
}
