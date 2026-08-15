//
//  BlockLayoutConfig.swift
//  AntAR
//

import RealityKit
import UIKit

enum BlockLayoutConfig {
    struct Entry {
        let name: String
        let color: UIColor
        let irMaterial: IRReflectanceComponent
        let positionOverride: SIMD3<Float>?
    }

    // TUNABLE — two black path blocks, two weaker dark-gray path blocks, and three light
    // obstacle blocks. IR behaviour is authored explicitly because visible RGB color is not a
    // reliable measurement of a real material's near-infrared response.
    static let entries: [Entry] = [
        Entry(
            name: "Block1",
            color: UIColor(white: 0.015, alpha: 1),
            irMaterial: .darkPath,
            positionOverride: nil
        ),
        Entry(
            name: "Block2",
            color: UIColor(white: 0.015, alpha: 1),
            irMaterial: .darkPath,
            positionOverride: nil
        ),
        Entry(
            name: "Block3",
            color: UIColor(white: 0.20, alpha: 1),
            irMaterial: .darkGrayPath,
            positionOverride: nil
        ),
        Entry(
            name: "Block4",
            color: UIColor(white: 0.25, alpha: 1),
            irMaterial: .darkGrayPath,
            positionOverride: nil
        ),
        Entry(
            name: "Block5",
            color: UIColor(white: 0.82, alpha: 1),
            irMaterial: .lightObstacle,
            positionOverride: nil
        ),
        Entry(
            name: "Block6",
            color: UIColor(white: 0.90, alpha: 1),
            irMaterial: .lightObstacle,
            positionOverride: nil
        ),
        Entry(
            name: "Block7",
            color: UIColor(white: 0.98, alpha: 1),
            irMaterial: .lightObstacle,
            positionOverride: nil
        ),
    ]

    /// Five route positions are required; the other two blocks are alternatives the learner can
    /// test and swap in without having to collect every scattered object first.
    static let requiredCount = BlockPlacementConfig.requiredPathBlockCount
}
