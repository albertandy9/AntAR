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
    let isReturnTargeted: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(isReturnTargeted
                ? "LEPAS UNTUK MENGEMBALIKAN"
                : "INVENTORY • tarik balok kembali ke sini")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(isReturnTargeted ? .yellow : .white.opacity(0.68))

            if collectedBlocks.isEmpty {
                Label("Tarik balok ke sini", systemImage: "tray.and.arrow.down.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isReturnTargeted ? .yellow : .white.opacity(0.82))
            } else {
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
            }
        }
        .frame(minWidth: 150, minHeight: 38)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isReturnTargeted ? Color.yellow.opacity(0.24) : Color.black.opacity(0.58),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    isReturnTargeted ? Color.yellow : Color.clear,
                    style: StrokeStyle(lineWidth: 3, dash: [8, 5])
                )
        )
        .scaleEffect(isReturnTargeted ? 1.06 : 1)
        .animation(.easeOut(duration: 0.14), value: isReturnTargeted)
        .animation(.spring(duration: 0.4), value: collectedBlocks.map(\.id))
    }
}
