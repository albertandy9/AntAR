//
//  OnboardingView.swift
//  AntAR
//

import SwiftUI

/// Design tokens for the onboarding screens.
enum AntARTheme {
    static let cardCream = Color(red: 253 / 255, green: 240 / 255, blue: 224 / 255)
    static let bronzeDark = Color(red: 107 / 255, green: 58 / 255, blue: 20 / 255)
    static let groundClay = Color(red: 74 / 255, green: 34 / 255, blue: 26 / 255)
    static let sunsetOrange = Color(red: 232 / 255, green: 150 / 255, blue: 91 / 255)

    static let bronzeButtonGradient = LinearGradient(
        colors: [
            Color(red: 138 / 255, green: 82 / 255, blue: 33 / 255),
            Color(red: 92 / 255, green: 51 / 255, blue: 17 / 255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let skyGradient = LinearGradient(
        colors: [
            Color(red: 134 / 255, green: 194 / 255, blue: 217 / 255),
            Color(red: 240 / 255, green: 149 / 255, blue: 75 / 255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    enum Metrics {
        static let cornerRadiusLarge: CGFloat = 28
        static let minTapTarget: CGFloat = 44
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                OnboardingBackground(pageIndex: pageIndex)

                VStack {
                    // Spacer atas diperbesar (0.35) agar kotak kartu lebih turun
                    Spacer()
                        .frame(height: geometry.size.height * 0.35)

                    OnboardingCard {
                        switch pageIndex {
                        case 0:
                            WelcomePage(onStart: advance)
                        default:
                            SafetyPage(onStart: advance)
                        }
                    }
                    // 299pt wide — matches the reference box spec exactly (capped against the
                    // available width so it doesn't overflow on narrower devices). Height stays
                    // content-hugging (OnboardingCard's own VStack), not forced to the reference's
                    // 313 — that number was just Figma's auto-layout result for that exact content,
                    // not an independent constraint worth risking clipped text over.
                    .frame(width: min(299, geometry.size.width - 40))

                    // Spacer bawah fleksibel untuk mendorong kartu dari bawah
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
    }

    private func advance() {
        withAnimation(.easeInOut) {
            if pageIndex == 0 {
                pageIndex = 1
            } else {
                onFinish()
            }
        }
    }
}

/// Cream rounded panel shared by both onboarding pages.
private struct OnboardingCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 20) {
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AntARTheme.cardCream, in: RoundedRectangle(cornerRadius: AntARTheme.Metrics.cornerRadiusLarge))
    }
}

/// Page 1: welcome card.
private struct WelcomePage: View {
    let onStart: () -> Void

    var body: some View {
        Text("ANT AR")
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(AntARTheme.bronzeDark)

        Text("Bantu semut menemukan sarangnya.")
            .font(.body)
            .foregroundStyle(AntARTheme.groundClay)
            .multilineTextAlignment(.center)

        OnboardingButton(title: "Mulai", systemImage: "play.fill", action: onStart)
    }
}

/// Page 2: safety reminder.
private struct SafetyPage: View {
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Cari Tempat yang Aman")
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AntARTheme.sunsetOrange, in: Capsule())

        Text("Game ini memerlukan anak untuk bergerak dan pastikan tidak terdapat banyak benda di area. Pastikan selalu memerhatikan keadaan sekitar")
            .font(.body)
            .foregroundStyle(AntARTheme.groundClay)
            .multilineTextAlignment(.center)

        OnboardingButton(title: "Lanjut", systemImage: nil, action: onStart)
    }
}

private struct OnboardingButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AntARTheme.Metrics.minTapTarget)
        }
        .background(AntARTheme.bronzeButtonGradient, in: Capsule())
    }
}

/// Background View — each page is a single pre-composited image ("Home Screen" / "Home Screen-1",
/// exported straight from the Figma reference: sky, clouds, leaf/UFO or pine/rock, ground, all
/// baked in), not individually placed asset layers. scaledToFill + clipped so it always covers the
/// full screen without distorting, cropping evenly instead of letterboxing on aspect ratios that
/// don't exactly match the export.
private struct OnboardingBackground: View {
    let pageIndex: Int

    var body: some View {
        Image(pageIndex == 0 ? "Home Screen" : "Home Screen-1")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

#Preview("Welcome") {
    OnboardingView(onFinish: {})
}
