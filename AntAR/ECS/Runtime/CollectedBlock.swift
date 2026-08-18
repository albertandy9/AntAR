//
//  CollectedBlock.swift
//  AntAR
//

import SwiftUI

struct CollectedBlock: Identifiable {
    let id: String
    let color: Color
    /// Which of the real block-rectangle image assets (red/blue/yellow/black-rectangle — the same
    /// art used for the actual draggable blocks) visually matches this block's color, for
    /// BlockInventoryView to show instead of a hand-drawn swatch. Only those 4 rectangle assets
    /// exist so far even though BlockLayoutConfig defines more colors (orange, green, indigo,
    /// purple) — anything without a dedicated asset falls back to "black-rectangle".
    let rectangleAssetName: String

    init(name: String, uiColor: UIColor) {
        self.id = name
        self.color = Color(uiColor)
        if uiColor == .systemRed {
            self.rectangleAssetName = "red-rectangle"
        } else if uiColor == .systemBlue {
            self.rectangleAssetName = "blue-rectangle"
        } else if uiColor == .systemYellow {
            self.rectangleAssetName = "yellow-rectangle"
        } else {
            self.rectangleAssetName = "black-rectangle"
        }
    }
}
