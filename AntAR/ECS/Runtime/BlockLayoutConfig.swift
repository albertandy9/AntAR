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
        let positionOverride: SIMD3<Float>?
    }

    static let entries: [Entry] = [
        Entry(name: "Block1", color: .systemRed, positionOverride: nil),
        Entry(name: "Block2", color: .systemOrange, positionOverride: nil),
        Entry(name: "Block3", color: .systemYellow, positionOverride: nil),
        Entry(name: "Block4", color: .systemGreen, positionOverride: nil),
        Entry(name: "Block5", color: .systemBlue, positionOverride: nil),
        Entry(name: "Block6", color: .systemIndigo, positionOverride: nil),
        Entry(name: "Block7", color: .systemPurple, positionOverride: nil),
    ]

    static let requiredCount = entries.count
}
