//
//  LevelCompletedView.swift
//  AntAR
//
//  End-of-level card projected from the authored nest's world position by ContentView.
//

import SwiftUI

struct LevelCompletedView: View {
    let onHome: () -> Void
    let onRestart: () -> Void

    private static let cardWidth: CGFloat = 260
    private static let cardFill = Color(red: 0xFD / 255, green: 0xEC / 255, blue: 0xDB / 255)
    private static let cardBorder = Color(red: 74 / 255, green: 42 / 255, blue: 20 / 255)
    private static let titleFill = Color(red: 76 / 255, green: 191 / 255, blue: 110 / 255)
    private static let buttonFill = Color(red: 0xF6 / 255, green: 0xB1 / 255, blue: 0x70 / 255)
    private static let buttonBorder = Color(red: 201 / 255, green: 140 / 255, blue: 68 / 255)
    private static let iconColor = Color(red: 0x59 / 255, green: 0x38 / 255, blue: 0x18 / 255)

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 22) {
                Image("Group 50")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 22)

                HStack(spacing: 22) {
                    actionButton(
                        systemImage: "house.fill",
                        accessibilityLabel: "Kembali ke menu",
                        action: onHome
                    )
                    actionButton(
                        systemImage: "arrow.counterclockwise",
                        accessibilityLabel: "Ulangi level",
                        action: onRestart
                    )
                }
                .padding(.bottom, 22)
            }
            .padding(.top, 56)
            .frame(width: Self.cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Self.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Self.cardBorder, lineWidth: 12)
            )

            Text("Completed")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Self.titleFill, in: Capsule())
                .offset(y: -26)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    }

    private func actionButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Self.iconColor)
                .frame(width: 62, height: 62)
                .background(Self.buttonFill, in: Circle())
                .overlay(Circle().stroke(Self.buttonBorder, lineWidth: 3))
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        LevelCompletedView(onHome: {}, onRestart: {})
    }
}
