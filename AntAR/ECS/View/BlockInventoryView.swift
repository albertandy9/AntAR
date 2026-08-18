//
//  BlockInventoryView.swift
//  AntAR
//

import SwiftUI
import UIKit

/// Vertical pill of 4 slots — moved to the screen's top-left corner (see ContentView), so this is
/// a plain VStack now, not the old side-by-side HStack. Slot art is the real block-rectangle image
/// assets (CollectedBlock.rectangleAssetName), not a hand-drawn swatch, so a block reads as "the
/// same block" the player just dragged in the AR scene.
struct BlockInventoryView: View {
    let collectedBlocks: [CollectedBlock]

    private static let slotCount = 4
    private static let containerFill = Color(red: 247 / 255, green: 213 / 255, blue: 168 / 255)
    private static let containerBorder = Color(red: 201 / 255, green: 140 / 255, blue: 68 / 255)

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<Self.slotCount, id: \.self) { index in
                slot(at: index)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(Self.containerFill, in: Capsule())
        .overlay(Capsule().stroke(Self.containerBorder, lineWidth: 2))
        .animation(.spring(duration: 0.4), value: collectedBlocks.map(\.id))
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        let block = index < collectedBlocks.count ? collectedBlocks[index] : nil
        RoundedRectangle(cornerRadius: 8)
            .fill(block == nil ? Color.white.opacity(0.55) : Color.clear)
            .frame(width: 36, height: 36)
            .overlay {
                if let block {
                    Image(block.rectangleAssetName)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.containerBorder.opacity(block == nil ? 0.5 : 1), lineWidth: 2))
            .shadow(radius: block == nil ? 0 : 2)
            .modifier(DraggableIfPresent(id: block?.id))
    }
}

/// `.draggable` needs a concrete value up front, so an empty slot (no block yet) just skips it
/// instead of being draggable with nothing to drag.
private struct DraggableIfPresent: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.draggable(id)
        } else {
            content
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack(spacing: 24) {
            BlockInventoryView(collectedBlocks: [])
            BlockInventoryView(collectedBlocks: [
                CollectedBlock(name: "block_red", uiColor: .systemRed),
                CollectedBlock(name: "block_blue", uiColor: .systemBlue)
            ])
            BlockInventoryView(collectedBlocks: [
                CollectedBlock(name: "block_red", uiColor: .systemRed),
                CollectedBlock(name: "block_blue", uiColor: .systemBlue),
                CollectedBlock(name: "block_yellow", uiColor: .systemYellow),
                CollectedBlock(name: "block_green", uiColor: .systemGreen)
            ])
        }
    }
}
