//
//  BlockInventoryView.swift
//  AntAR
//
//  Vertical pill, top-left corner (see ContentView) — always exactly 4 slots, one per known block
//  color (red/blue/yellow, then black last), shown EMPTY from the very start rather than only
//  appearing once something's been collected. There are only 4 rectangle color assets, so "one
//  fixed slot per color" and "group same-color blocks together" are the same design: a slot fills
//  in with that color's block art (+ "×N" badge once N>1) the moment the first block of that color
//  is collected, and stays filled/updates in place after that.
//
//  Filled slots use an immediate zero-distance drag gesture instead of SwiftUI's delayed
//  transferable drag. ContentView receives the representative block id and places it when the
//  drag ends over the AR area. Empty slots aren't draggable (nothing to drag yet).
//
//  isReturnTargeted mirrors ARExperienceViewModel-driven state from ContentView (true while a
//  placed-on-the-table block is being dragged back over this view) — shown as a yellow dashed
//  ring + scale bump.
//

import SwiftUI
import UIKit

struct BlockInventoryView: View {
    let collectedBlocks: [CollectedBlock]
    let isReturnTargeted: Bool
    let selectedBlockID: String?
    let onBlockDragChanged: (_ blockID: String, _ location: CGPoint) -> Void
    let onBlockDragEnded: (_ blockID: String, _ location: CGPoint, _ translation: CGSize) -> Void

    private static let slotSize: CGFloat = 44
    private static let containerFill = Color(red: 247 / 255, green: 213 / 255, blue: 168 / 255)
    private static let containerBorder = Color(red: 201 / 255, green: 140 / 255, blue: 68 / 255)
    private static let slotBorder = Color(red: 0xF6 / 255, green: 0xB1 / 255, blue: 0x70 / 255)
    private static let selectedSlotBorder = Color(red: 0xC8 / 255, green: 0x81 / 255, blue: 0x3D / 255)
    // 20 -> 14: too rounded, per reference.
    private static let containerCornerRadius: CGFloat = 14
    private static let slotCornerRadius: CGFloat = 7
    // Fixed order: every non-black color first (in this fixed order), black always last — matches
    // the only 4 rectangle assets that currently exist.
    private static let colorOrder = ["red-rectangle", "blue-rectangle", "yellow-rectangle", "black-rectangle"]

    private struct Slot: Identifiable {
        let assetName: String
        let count: Int
        // Which single collected block this slot actually drags/represents when count > 0 —
        // always a real, currently-uncollected-elsewhere block.id, so placeBlockInFrontOfUFO
        // (blockID:) and the rest of the existing drag/drop plumbing don't need to know grouping
        // exists at all.
        let representativeID: String?
        var id: String { assetName }
    }

    private var slots: [Slot] {
        var counts: [String: Int] = [:]
        var representativeIDs: [String: String] = [:]

        for block in collectedBlocks {
            let asset = Self.rectangleAssetName(for: block)
            if representativeIDs[asset] == nil {
                representativeIDs[asset] = block.id
            }
            counts[asset, default: 0] += 1
        }

        return Self.colorOrder.map { asset in
            Slot(assetName: asset, count: counts[asset] ?? 0, representativeID: representativeIDs[asset])
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(slots) { slot in
                slotView(for: slot)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        // Fill AND stroke both live in .background now, not a trailing .overlay — an .overlay
        // here would draw on top of EVERY child, including each slot's own count badge, which is
        // exactly what was slicing the badge circle where it crossed the capsule's border line.
        // .background always draws behind the content, so the border no longer covers anything.
        .background(
            RoundedRectangle(cornerRadius: Self.containerCornerRadius)
                .fill(isReturnTargeted ? Color.yellow.opacity(0.30) : Self.containerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.containerCornerRadius).stroke(
                        isReturnTargeted ? Color.yellow : Self.containerBorder,
                        // 2 -> 1.5: stroke was too thick, per reference.
                        style: StrokeStyle(lineWidth: isReturnTargeted ? 3 : 1.5, dash: isReturnTargeted ? [8, 5] : [])
                    )
                )
        )
        .scaleEffect(isReturnTargeted ? 1.06 : 1)
        .animation(.easeOut(duration: 0.14), value: isReturnTargeted)
        .animation(.spring(duration: 0.4), value: collectedBlocks.map(\.id))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isReturnTargeted ? "Lepas untuk mengembalikan" : "Inventory balok")
    }

    @ViewBuilder
    private func slotView(for slot: Slot) -> some View {
        let base = RoundedRectangle(cornerRadius: Self.slotCornerRadius)
            .fill(slot.count == 0 ? Self.containerFill : Color.clear)
            .frame(width: Self.slotSize, height: Self.slotSize)
            .overlay {
                if slot.count > 0 {
                    Image(slot.assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Self.slotCornerRadius)
                    .stroke(
                        slot.representativeID == selectedBlockID ? Self.selectedSlotBorder : Self.slotBorder,
                        lineWidth: slot.representativeID == selectedBlockID ? 4 : (slot.count == 0 ? 1.5 : 2)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if slot.count > 1 {
                    // Plain number, not "×N" — a small white circle with a dark outline and just
                    // the digit, matching the reference instead of a "×" capsule.
                    Text("\(slot.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white))
                        .overlay(Circle().stroke(Self.slotBorder, lineWidth: 1.5))
                        .offset(x: 8, y: -8)
                }
            }
            .shadow(radius: slot.count == 0 ? 0 : 2)
            .scaleEffect(slot.representativeID == selectedBlockID ? 1.08 : 1)
            .animation(.easeOut(duration: 0.1), value: selectedBlockID)

        if let representativeID = slot.representativeID {
            base.gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        onBlockDragChanged(representativeID, value.location)
                    }
                    .onEnded { value in
                        onBlockDragEnded(representativeID, value.location, value.translation)
                    }
            )
        } else {
            base
        }
    }

    /// Which real block-rectangle asset (only red/blue/yellow/black exist so far) visually matches
    /// this block's color.
    ///
    /// BUG FIXED: this used to compare `UIColor(block.color) == .systemRed/.systemBlue/
    /// .systemYellow` — but BlockLayoutConfig.entries doesn't actually spawn Apple's exact system
    /// colors, it uses its own custom UIColor(red:green:blue:) values (e.g. (0.96, 0.18, 0.14) for
    /// "red", (1.00, 0.84, 0.08) for "yellow") and two shades of near-black/dark-gray for the path
    /// blocks. None of those are bit-for-bit equal to .systemRed/.systemYellow, so the equality
    /// check almost always failed and silently fell through to the "black-rectangle" default —
    /// which is exactly why a freshly-collected yellow or red block still showed up as black.
    /// Classifying by hue/brightness/saturation instead matches on what the color actually looks
    /// like, not on which exact UIColor constant produced it.
    private static func rectangleAssetName(for block: CollectedBlock) -> String {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(block.color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // BlockLayoutConfig's "path" blocks are near-black/dark-gray (low brightness, ~0 or low
        // saturation) — these are the ones actually meant to read as "black" here.
        if brightness < 0.35 || saturation < 0.15 {
            return "black-rectangle"
        }

        switch hue {
        case 0..<0.045, 0.95...1:
            return "red-rectangle"
        case 0.08..<0.20:
            return "yellow-rectangle"
        case 0.55..<0.72:
            return "blue-rectangle"
        default:
            // Includes green (BlockLayoutConfig's Block6) — there's no green-rectangle asset yet,
            // so this still isn't fully correct for that one color. Flagged, not silently "fixed"
            // by guessing a stand-in asset.
            return "black-rectangle"
        }
    }
}
#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        HStack(alignment: .top, spacing: 30) {
            // All 4 slots empty from the start — no items collected yet.
            BlockInventoryView(
                collectedBlocks: [],
                isReturnTargeted: false,
                selectedBlockID: nil,
                onBlockDragChanged: { _, _ in },
                onBlockDragEnded: { _, _, _ in }
            )
            // Black (picked up FIRST) still sits in its fixed last slot, and the two reds share
            // one slot with a ×2 badge — yellow's slot stays empty.
            BlockInventoryView(
                collectedBlocks: [
                    CollectedBlock(name: "block_black_1", uiColor: .black),
                    CollectedBlock(name: "block_red_1", uiColor: .systemRed),
                    CollectedBlock(name: "block_blue", uiColor: .systemBlue),
                    CollectedBlock(name: "block_red_2", uiColor: .systemRed)
                ],
                isReturnTargeted: false,
                selectedBlockID: nil,
                onBlockDragChanged: { _, _ in },
                onBlockDragEnded: { _, _, _ in }
            )
            BlockInventoryView(
                collectedBlocks: [
                    CollectedBlock(name: "block_red", uiColor: .systemRed),
                    CollectedBlock(name: "block_blue", uiColor: .systemBlue)
                ],
                isReturnTargeted: true,
                selectedBlockID: nil,
                onBlockDragChanged: { _, _ in },
                onBlockDragEnded: { _, _, _ in }
            )
        }
        .padding()
    }
}
