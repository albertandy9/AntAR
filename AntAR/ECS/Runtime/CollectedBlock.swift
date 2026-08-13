//
//  CollectedBlock.swift
//  AntAR
//

import SwiftUI

struct CollectedBlock: Identifiable {
    let id: String
    let color: Color

    init(name: String, uiColor: UIColor) {
        self.id = name
        self.color = Color(uiColor)
    }
}
