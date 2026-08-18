//
//  CaptionPill.swift
//  AntAR
//

import SwiftUI

struct CaptionPill: View {
    let text: String

    var body: some View {
        Text(text)
            // Typography: Nunito Regular, 16px
            .font(.custom("Nunito-Regular", size: 16))
            // Warna teks: #000000 (Hitam)
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(red: 254/255, green: 245/255, blue: 237/255))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 4)
            )
    }
}
