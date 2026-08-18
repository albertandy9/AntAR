//
//  UFOAppearsView.swift
//  AntAR
//

import SwiftUI

/// A projected, non-interactive visual cue. ContentView positions it over the authored UFO while
/// the AR tap gesture remains responsible for the actual entity hit test.
struct UFOAppearsView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.85), lineWidth: 3)
                .frame(width: 64, height: 64)
                .scaleEffect(isPulsing ? 1.35 : 0.82)
                .opacity(isPulsing ? 0 : 0.9)

            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.28), radius: 8, y: 4)

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AntARTheme.bronzeDark)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
        .accessibilityLabel("Ketuk UFO")
    }
}
