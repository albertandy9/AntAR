////
////  BoardHintBubbleView.swift
////  AntAR
////
//
//import SwiftUI
//import UIKit
//
//struct BoardHintBubbleView: View {
//    let message: String
//    let onDismiss: () -> Void
//
//    // Warna disesuaikan dengan referensi gambar (Cyan/Teal)
//    private let bubbleFillColor = Color(red: 91 / 255, green: 154 / 255, blue: 166 / 255)
//    private let bubbleShadowColor = Color(red: 54 / 255, green: 99 / 255, blue: 108 / 255)
//
//    var body: some View {
//        VStack {
//            Spacer()
//
//            HStack(spacing: 0) {
//                // Zero — the arm's own offset below is what reaches the edge, not this gap.
//                Spacer(minLength: 0)
//
//                // ZStack, not HStack — the ant sits low and to the left of the bubble, overlapping
//                // its bottom-left corner. Bubble drawn FIRST (bottom layer) and ant SECOND (top
//                // layer) now — the opposite of SpeechBubbleView's convention — so the ant's full
//                // pose (head + both arms) stays visible in front instead of being clipped by the
//                // bubble shape.
//                ZStack(alignment: .topLeading) {
//                    // Ant drawn FIRST (bottom layer) again — same convention as
//                    // StoryBubbleSequenceView's SpeechBubbleView — so the bubble paints over it.
//                    Image("Group 38")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 150)
//                        // Specifically the extended arm/stick's tip (the left-pointing appendage,
//                        // near the image's own left edge) that should touch the screen's left
//                        // edge — not the ant's body/head, which stays mostly on-screen.
//                        .offset(x: -56, y: 45)
//
//                    Text(message)
//                        .font(.custom("Fredoka-SemiBold", size: 18))
//                        .multilineTextAlignment(.center)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: 230)
//                        .padding(.vertical, 16)
//                        .padding(.horizontal, 20)
//                        .padding(.bottom, 16)
//                        .background(
//                            BottomLeftTailBubbleShape()
//                                .fill(bubbleFillColor)
//                                .shadow(color: bubbleShadowColor, radius: 0, x: 0, y: 6)
//                        )
//                        .overlay(alignment: .bottomTrailing) {
//                            DialogueAdvanceIndicator()
//                                .padding(.trailing, 16)
//                                .padding(.bottom, 8)
//                                .accessibilityHidden(true)
//                        }
//                        // Shifts the whole bubble (shape + text together, since offset applies
//                        // after .background) right and down relative to the ant.
//                        .offset(x: 60, y: 30)
//                }
//                .padding(.bottom, 46)
//
//                Spacer(minLength: 8)
//            }
//            .padding(.trailing, 20)
//            // 180, not 100 — sits just above the IR panel + gas pedal, matching the earlier tuning.
//            .padding(.bottom, 180)
//        }
//        .contentShape(Rectangle())
//        .onTapGesture {
//            UIImpactFeedbackGenerator(style: .light).impactOccurred()
//            onDismiss()
//        }
//    }
//}
//
///// Rounded bubble with a small tail poking out of the bottom-left corner (pointing down toward the
///// ant below it), instead of a tail centered on the left edge.
//struct BottomLeftTailBubbleShape: Shape {
//    var cornerRadius: CGFloat = 20
//    var tailWidth: CGFloat = 20
//    var tailHeight: CGFloat = 20
//    var tailInset: CGFloat = 34
//
//    func path(in rect: CGRect) -> Path {
//        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
//        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)
//
//        let tailBaseLeft = CGPoint(x: bubbleRect.minX + tailInset, y: bubbleRect.maxY)
//        let tailBaseRight = CGPoint(x: bubbleRect.minX + tailInset + tailWidth, y: bubbleRect.maxY)
//        let tailTip = CGPoint(x: bubbleRect.minX + tailInset - 8, y: rect.maxY)
//
//        path.move(to: tailBaseLeft)
//        path.addLine(to: tailTip)
//        path.addLine(to: tailBaseRight)
//        path.closeSubpath()
//
//        return path
//    }
//}
//
//// MARK: - Preview
//
//#Preview {
//    ZStack {
//        // Background abu-abu untuk memperjelas batas elemen UI dan shadow
//        Color.gray
//            .ignoresSafeArea()
//
//        BoardHintBubbleView(
//            message: "UFO belum bisa bergerak. Yuk cari balok di sekitar terlebih dahulu!",
//            onDismiss: {}
//        )
//    }
//}
//
//  BoardHintBubbleView.swift
//  AntAR
//

import SwiftUI
import UIKit

struct BoardHintBubbleView: View {
    let message: String
    let onDismiss: () -> Void

    // Warna disesuaikan dengan referensi gambar (Cyan/Teal)
    private let bubbleFillColor = Color(red: 91 / 255, green: 154 / 255, blue: 166 / 255)
    private let bubbleShadowColor = Color(red: 54 / 255, green: 99 / 255, blue: 108 / 255)

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack(alignment: .topLeading) {
                    Image("Group 38")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150)
                        .offset(x: -70, y: 45)

                    Text(message)
                        .font(.custom("Fredoka-SemiBold", size: 16))
                        .multilineTextAlignment(.leading) // Condong / rata kiri
                        .foregroundColor(.white)
                        .frame(maxWidth: 230, alignment: .leading) // Rapat kiri dalam frame
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .background(
                            BottomLeftTailBubbleShape()
                                .fill(bubbleFillColor)
                                .shadow(color: bubbleShadowColor, radius: 0, x: 0, y: 6)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            DialogueAdvanceIndicator()
                                .padding(.trailing, 16)
                                .padding(.bottom, 26) // Dinaikkan (sebelumnya 8)
                                .accessibilityHidden(true)
                        }
                        .offset(x: 60, y: 30)
                }
                .padding(.bottom, 46)

                Spacer(minLength: 8)
            }
            // Same fix as UFOTravelDialogueView/SensorCountHintView — makes the leading-vs-trailing
            // Spacer split explicit instead of relying on both Spacers dividing leftover width.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 20)
            .padding(.bottom, 180)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            ExperienceFeedback.shared.impact(.light)
            onDismiss()
        }
    }
}

/// Rounded bubble dengan tail di kiri bawah.
struct BottomLeftTailBubbleShape: Shape {
    var cornerRadius: CGFloat = 20
    var tailWidth: CGFloat = 20
    var tailHeight: CGFloat = 20
    var tailInset: CGFloat = 34

    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)

        let tailBaseLeft = CGPoint(x: bubbleRect.minX + tailInset, y: bubbleRect.maxY)
        let tailBaseRight = CGPoint(x: bubbleRect.minX + tailInset + tailWidth, y: bubbleRect.maxY)
        let tailTip = CGPoint(x: bubbleRect.minX + tailInset - 8, y: rect.maxY)

        path.move(to: tailBaseLeft)
        path.addLine(to: tailTip)
        path.addLine(to: tailBaseRight)
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray
            .ignoresSafeArea()

        BoardHintBubbleView(
            message: "UFO belum bisa bergerak. Yuk cari balok di sekitar terlebih dahulu!",
            onDismiss: {}
        )
    }
}
