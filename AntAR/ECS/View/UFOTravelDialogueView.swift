//
//  UFOTravelDialogueView.swift
//  AntAR
//

//import SwiftUI
//import UIKit
//
///// Figma-style ant dialogue used by the state-10 learning loop instead of system alerts.
//struct UFOTravelDialogueView: View {
//    let dialogue: UFOTravelDialogue
//    let onComplete: () -> Void
//
//    @State private var messageIndex = 0
//
//    private static let bubbleFill = Color(red: 98 / 255, green: 165 / 255, blue: 183 / 255)
//    private static let bubbleShadow = Color(red: 35 / 255, green: 85 / 255, blue: 99 / 255)
//    private static let textColor = Color(red: 252 / 255, green: 226 / 255, blue: 201 / 255)
//
//    private var currentMessage: String {
//        dialogue.messages[min(messageIndex, dialogue.messages.count - 1)]
//    }
//
//    var body: some View {
//        VStack {
//            Spacer()
//
//            HStack(alignment: .bottom, spacing: -18) {
//                Image(dialogue.avatarImageName)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 122)
//                    .zIndex(1)
//
//                Button(action: advance) {
//                    Text(currentMessage)
//                        .font(.custom("Fredoka-Regular", size: 16))
//                        .foregroundStyle(Self.textColor)
//                        .multilineTextAlignment(.leading)
//                        .frame(maxWidth: 230)
//                        .padding(.top, 16)
//                        .padding(.horizontal, 22)
//                        .padding(.bottom, 28)
//                        .background(
//                            LeadingTailBubbleShape()
//                                .fill(Self.bubbleFill)
//                                .shadow(color: Self.bubbleShadow, radius: 0, x: 2, y: 6)
//                        )
//                        .overlay(alignment: .bottomTrailing) {
//                            DialogueAdvanceIndicator()
//                                .padding(.trailing, 9)
//                                .padding(.bottom, 8)
//                        }
//                }
//                .buttonStyle(.plain)
//                .accessibilityLabel(currentMessage)
//                .accessibilityHint(
//                    messageIndex + 1 < dialogue.messages.count
//                        ? "Ketuk untuk melanjutkan dialog"
//                        : "Ketuk untuk menutup dialog"
//                )
//                .offset(x: -8, y: -8)
//            }
//            .padding(.horizontal, 10)
//            .padding(.bottom, 182)
//        }
//        .transition(.move(edge: .bottom).combined(with: .opacity))
//        .onChange(of: dialogue) { _, _ in
//            messageIndex = 0
//        }
//    }
//
//    private func advance() {
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//        if messageIndex + 1 < dialogue.messages.count {
//            withAnimation(.easeInOut(duration: 0.18)) {
//                messageIndex += 1
//            }
//        } else {
//            onComplete()
//        }
//    }
//}
//
//private struct LeadingTailBubbleShape: Shape {
//    private let tailWidth: CGFloat = 16
//    private let tailHeight: CGFloat = 20
//    private let cornerRadius: CGFloat = 18
//
//    func path(in rect: CGRect) -> Path {
//        let bubbleRect = CGRect(
//            x: rect.minX + tailWidth,
//            y: rect.minY,
//            width: rect.width - tailWidth,
//            height: rect.height
//        )
//        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)
//        let centerY = bubbleRect.midY - 4
//
//        path.move(to: CGPoint(x: bubbleRect.minX, y: centerY - tailHeight / 2))
//        path.addLine(to: CGPoint(x: rect.minX, y: centerY))
//        path.addLine(to: CGPoint(x: bubbleRect.minX, y: centerY + tailHeight / 2))
//        path.closeSubpath()
//        return path
//    }
//}
//
//  UFOTravelDialogueView.swift
//  AntAR
//

import SwiftUI
import UIKit

/// Figma-style ant dialogue used by the state-10 learning loop instead of system alerts.
struct UFOTravelDialogueView: View {
    let dialogue: UFOTravelDialogue
    let onComplete: () -> Void

    @State private var messageIndex = 0

    private static let bubbleFill = Color(red: 98 / 255, green: 165 / 255, blue: 183 / 255)
    private static let bubbleShadow = Color(red: 35 / 255, green: 85 / 255, blue: 99 / 255)
    private static let textColor = Color(red: 252 / 255, green: 226 / 255, blue: 201 / 255)

    private var currentMessage: String {
        dialogue.messages[min(messageIndex, dialogue.messages.count - 1)]
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(alignment: .bottom, spacing: -18) {
                Image(dialogue.avatarImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 165)
                    .offset(x: -9)
                    .ignoresSafeArea(edges: .leading)

                Button(action: advance) {
                    Text(currentMessage)
                        .font(.custom("Fredoka-Regular", size: 15))
                        .foregroundStyle(Self.textColor)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 190, alignment: .leading) // <--- TAMBAH alignment: .leading agar teks rata kiri
                        .padding(.top, 16)
                        .padding(.leading, 40)
                        .padding(.trailing, 10)                        .padding(.bottom, 28)
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
                .zIndex(1) // <--- PINDAHKAN KE SINI agar bubble maju ke depan
                .accessibilityLabel(currentMessage)
                .accessibilityHint(
                    messageIndex + 1 < dialogue.messages.count
                        ? "Ketuk untuk melanjutkan dialog"
                        : "Ketuk untuk menutup dialog"
                )
                .offset(x: -6, y: -40)
            }
            // Claims the full width and left-aligns its content instead of sizing to fit — without
            // this, ContentView's ZStack (default .center alignment) centers the whole block on
            // screen since nothing here was reserving/filling the rest of the row.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.bottom, 175)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onChange(of: dialogue) { _, _ in
            messageIndex = 0
        }
    }

    private func advance() {
        ExperienceFeedback.shared.impact(.light)
        if messageIndex + 1 < dialogue.messages.count {
            withAnimation(.easeInOut(duration: 0.18)) {
                messageIndex += 1
            }
        } else {
            onComplete()
        }
    }
}

struct LeadingTailBubbleShape: Shape {
    private let tailWidth: CGFloat = 16
    private let tailHeight: CGFloat = 20
    private let cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(
            x: rect.minX + tailWidth,
            y: rect.minY,
            width: rect.width - tailWidth,
            height: rect.height
        )
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)
        let centerY = bubbleRect.midY - 4

        path.move(to: CGPoint(x: bubbleRect.minX, y: centerY - tailHeight / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: centerY))
        path.addLine(to: CGPoint(x: bubbleRect.minX, y: centerY + tailHeight / 2))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        UFOTravelDialogueView(dialogue: .lightBlock, onComplete: {})
    }
}
