//
//  LostAntDialogueView.swift
//  AntAR
//


import SwiftUI

struct LostAntDialogueView: View {
    let phase: LostAntGreetPhase?

    var body: some View {
        switch phase {
        case .waiting, .rising, .chatting:
            captionAtScanningTablePosition(text: "Dekatkan tanganmu ke semut")
        case .releasing, .returning:
            CaptionPill(text: "Sekarang, turunkan tanganmu")
        case .arrived, .done, nil:
            EmptyView()
        }
    }

    private func captionAtScanningTablePosition(text: String) -> some View {
        VStack(spacing: 20) {
            CaptionPill(text: text)
            Color.clear.frame(width: ScanningTableView.reticleSize, height: ScanningTableView.reticleSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
