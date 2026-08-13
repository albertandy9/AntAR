//
//  BlockInventoryView.swift
//  AntAR
//
//  2D SwiftUI overlay (not part of the AR world) showing every block collected so far, in the
//  order they were tapped. Simple row of colored squares, each one overlapping the previous by a
//  few points to read as a "pile" growing as more blocks come in.
//
//  Each square is draggable (verified against the SDK: String already conforms to Transferable,
//  so dragging block.id directly needs no custom Transferable type). ContentView's RealityView
//  is the drop target — dropping anywhere on the AR view places that block's real 3D entity in
//  front of the UFO, see ARExperienceViewModel.placeBlockInFrontOfUFO(blockID:).
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
