//
//  BlockInventoryView.swift
//  AntAR
//

import SwiftUI

struct BlockInventoryView: View {
    let collectedBlocks: [CollectedBlock]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(collectedBlocks) { block in
                RoundedRectangle(cornerRadius: 6)
                    .fill(block.color)
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 2))
                    .shadow(radius: 2)
                    .draggable(block.id)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.58), in: Capsule())
        .animation(.spring(duration: 0.4), value: collectedBlocks.map(\.id))
    }
}
