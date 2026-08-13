//
//  ScanningTableView.swift
//  AntAR
//
//  Created by Albert Tandy Harison on 12/08/26.
//

import SwiftUI

struct ScanningTableView: View {
    let isReadyToPlace: Bool

    var body: some View {
        InstructionBanner(
            text: isReadyToPlace ? "Meja terdeteksi ✓ — tap di tengah meja" : "Arahkan kamera ke meja untuk memulai scan"
        )
        .animation(.default, value: isReadyToPlace)
    }
}
