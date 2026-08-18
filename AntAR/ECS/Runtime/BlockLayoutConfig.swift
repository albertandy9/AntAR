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

    // TUNABLE — four black path blocks and three bright red/blue/yellow obstacle blocks.
    // IR behaviour is authored explicitly because visible RGB
    // color is not a reliable measurement of a real material's near-infrared response.
    static let entries: [Entry] = [
        Entry(
            name: "Block1",
            color: UIColor(red: 0.96, green: 0.18, blue: 0.14, alpha: 1),
            irMaterial: .lightObstacle,
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
            color: UIColor(red: 0.16, green: 0.46, blue: 0.96, alpha: 1),
            irMaterial: .lightObstacle,
            positionOverride: nil
        ),
        Entry(
            name: "Block4",
            color: UIColor(white: 0.015, alpha: 1),
            irMaterial: .darkPath,
            positionOverride: nil
        ),
        Entry(
            name: "Block5",
            color: UIColor(white: 0.015, alpha: 1),
            irMaterial: .darkPath,
            positionOverride: nil
        ),
        Entry(
            name: "Block6",
            color: UIColor(red: 1.00, green: 0.84, blue: 0.08, alpha: 1),
            irMaterial: .lightObstacle,
            positionOverride: nil
        ),
        Entry(
            name: "Block7",
            color: UIColor(white: 0.015, alpha: 1),
            irMaterial: .darkPath,
            positionOverride: nil
        ),
    ]

    /// Five route positions are required; the other two blocks are alternatives the learner can
    /// test and swap in without having to collect every scattered object first.
    static let requiredCount = BlockPlacementConfig.requiredPathBlockCount
}
