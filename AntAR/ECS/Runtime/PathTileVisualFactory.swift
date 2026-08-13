//
//  PathTileVisualFactory.swift
//  AntAR
//

import RealityKit
import UIKit

/// Keeps a placed route tile's visible material aligned with its IR teaching data.
///
/// The tile mesh itself belongs to `Scene.usda`; only its material changes when the player swaps
/// a dark absorbing block for a light reflective one.
@MainActor
enum PathTileVisualFactory {
    static func apply(_ material: PathTileMaterial, to tile: Entity) {
        guard var model = tile.components[ModelComponent.self] else { return }

        let color: UIColor
        switch material {
        case .dark:
            color = UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1)
        case .light:
            color = UIColor(red: 0.96, green: 0.84, blue: 0.26, alpha: 1)
        }

        model.materials = [SimpleMaterial(color: color, isMetallic: false)]
        tile.components[ModelComponent.self] = model
    }
}
