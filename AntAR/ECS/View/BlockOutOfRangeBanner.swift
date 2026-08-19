//
//  BlockOutOfRangeBanner.swift
//  AntAR
//
//  The "block too far to collect" warning — used to be the shared InstructionBanner (black pill,
//  white text, near the top of the screen). The reference instead shows a light/cream tooltip with
//  dark text, sitting right above the IR panel, not near the top. No tail — plain rounded rect.
//

import SwiftUI

struct BlockOutOfRangeBanner: View {
    private static let fillColor = Color(red: 253 / 255, green: 246 / 255, blue: 238 / 255)
    private static let textColor = Color(red: 61 / 255, green: 41 / 255, blue: 20 / 255)
    private static let shadowColor = Color.black.opacity(0.18)

    var body: some View {
        Text("Mendekat ke balok untuk mengambil")
            .font(.callout.weight(.semibold))
            .foregroundStyle(Self.textColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Self.fillColor)
                    .shadow(color: Self.shadowColor, radius: 4, x: 0, y: 2)
            )
    }
}
#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        BlockOutOfRangeBanner()
    }
}
