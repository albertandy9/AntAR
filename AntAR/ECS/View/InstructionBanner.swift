//
//  InstructionBanner.swift
//  AntAR
//
//  Shared styling for every per-state instruction banner. ScanningTableView and UFOAppearsView
//  were each independently re-declaring the same font/color/padding/background chain — with more
//  states (and their views) still to come, that duplication would only grow. Every future
//  per-state view should use this instead of re-declaring the styling itself.
//

import SwiftUI

struct InstructionBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.58), in: Capsule())
    }
}
