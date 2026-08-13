//
//  IRReflectanceComponent.swift
//  AntAR
//

import RealityKit
import UIKit

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

    /// Derives the teaching material from the exact display color supplied by the incoming block
    /// system. This keeps visible color and simulated IR response on the same source of truth.
    public static func from(displayColor color: UIColor) -> IRReflectanceComponent {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .darkPath
        }

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        let isDark = luminance < 0.58
        return IRReflectanceComponent(
            reflectance: isDark ? 0.08 : 0.92,
            isValidPath: isDark
        )
    }
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
