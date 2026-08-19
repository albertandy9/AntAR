//
//  SensorCountHintView.swift
//  AntAR
//

import SwiftUI

/// One-shot instruction shown after the learner taps the pulsing UFO to inspect its sensors.
/// It intentionally does not add a full-screen input blocker: the learner can dismiss the bubble,
/// adjust the sensors, or press Selesai, which also dismisses it.
struct SensorCountHintView: View {
    let onDismiss: () -> Void

    private static let bubbleFill = Color(red: 98 / 255, green: 165 / 255, blue: 183 / 255)
    private static let bubbleShadow = Color(red: 35 / 255, green: 85 / 255, blue: 99 / 255)
    private static let textColor = Color(red: 252 / 255, green: 226 / 255, blue: 201 / 255)

    var body: some View {
        VStack {
            Spacer()

            HStack(alignment: .bottom, spacing: -18) {
                Image("Group 43")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 165)
                    .offset(x: -15)

                Button(action: dismiss) {
                    Text("Coba ubah jumlah sensornya!")
                        .font(.custom("Fredoka-Regular", size: 17))
                        .foregroundStyle(Self.textColor)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 190, alignment: .leading)
                        .padding(.top, 16)
                        .padding(.leading, 50)
                        .padding(.bottom, 28)
                        .background(
                            LeadingTailBubbleShape()
                                .fill(Self.bubbleFill)
                                .shadow(color: Self.bubbleShadow, radius: 0, x: 2, y: 6)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            DialogueAdvanceIndicator()
                                .padding(.trailing, 9)
                                .padding(.bottom, 8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Coba ubah jumlah sensornya")
                .accessibilityHint("Ketuk untuk menutup petunjuk")
                .offset(x: -6, y: -40)
            }
            // Same fix as UFOTravelDialogueView — without this, the parent ZStack's default
            // .center alignment centers this whole block instead of pinning it to the left edge.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.bottom, 182)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func dismiss() {
        ExperienceFeedback.shared.impact(.light)
        onDismiss()
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        SensorCountHintView(onDismiss: {})
    }
}
