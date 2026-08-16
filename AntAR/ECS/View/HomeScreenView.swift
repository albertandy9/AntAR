//
//  HomeScreenView.swift
//  AntAR
//
//  Shown before the AR camera ever starts. One sentence, one button — nothing else. Camera
//  permission + tracking only start once the user taps Start (see ContentView), not on launch.
//

import SwiftUI

struct HomeScreenView: View {
    // Placeholder — wording to be decided later.
    private let sentence = "GANTI ONBOARDING INI YA MORENO HEHE"
    private let buttonTitle = "Start"

    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Text(sentence)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onStart) {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
            }
        }
    }
}

#Preview {
    HomeScreenView(onStart: {})
}
