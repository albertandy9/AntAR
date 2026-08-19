//
//  SpeachBubbleView.swift
//  AntAR
//
//  Created by Albert Tandy Harison on 18/08/26.
//

import SwiftUI

struct SpeechBubbleView: View {
    let text: String
    // Optional character avatar (e.g. "Group 44" — the fainted ant with its own white oval shadow
    // baked into the asset) — when set, it's anchored above the bubble's top-leading corner,
    // overlapping down onto the bubble near the tail, matching the reference layout where the
    // character sits on top of its own dialogue rather than beside it.
    var avatarImageName: String? = nil

    private static let textColor = Color(red: 252/255, green: 226/255, blue: 201/255)   // #FCE2C9
    private static let fillColor = Color(red: 98/255, green: 165/255, blue: 183/255)    // #62A5B7
    private static let shadowColor = Color(red: 35/255, green: 85/255, blue: 99/255)    // #235563
    // Width only, no fixed height — "Group 44" (ant + its own oval shadow) is a wide/landscape
    // image, so constraining it into a SQUARE frame with scaledToFit left transparent letterboxing
    // above and below the actual artwork; the negative y-offset below then overlapped that empty
    // padding into the bubble instead of the ant itself, leaving a visible gap. Letting height come
    // from the image's own aspect ratio means the offset overlaps the real pixels.
    // 240 — "Group 44"'s real pixel size is 195x96 (checked via sips), a ~2:1 aspect ratio, not
    // the ~1.7:1 this was eyeballed at before; that earlier wrong guess is why bumping the width
    // barely changed the rendered size — the height (and therefore how far the overlap below
    // actually reaches into the bubble) was smaller than intended each time.
    private static let avatarWidth: CGFloat = 240

    var body: some View
//    {
//        Text(text)
//            .font(.custom("Fredoka-Regular", size: 20))
//            .foregroundStyle(Self.textColor)
//            .multilineTextAlignment(.leading)
//            .frame(maxWidth: 330)
//            .padding(.top, avatarImageName == nil ? 34 : 50)
//            .padding(.bottom, 24)
//            .padding(.horizontal, 20)
//            .background(
//                SpeechBubbleShape(tailInset: avatarImageName == nil ? 80 : 225)
//                    .fill(Self.fillColor)
//                    .shadow(color: Self.shadowColor, radius: 0, x: 2, y: 7)
//            )
//            // The arrow is attached to the bubble itself. The avatar is a separate overlay and
//            // therefore cannot expand the layout bounds or push this indicator down the screen.
//            .overlay(alignment: .bottomTrailing) {
//                DialogueAdvanceIndicator()
//                    .padding(.trailing, 16)
//                    .padding(.bottom, 8)
//                    .accessibilityHidden(true)
//            }
//            .overlay(alignment: .topLeading) {
//                if let avatarImageName {
//                    Image(avatarImageName)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: Self.avatarWidth)
//                        .offset(x: -30, y: -60)
//                }
//            }
//            .fixedSize(horizontal: false, vertical: true)
//            .animation(.default, value: text)
//    }
    {
        Text(text)
            .font(.custom("Fredoka-Regular", size: 20))
            .foregroundStyle(Self.textColor)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 330, alignment: .leading)
            .padding(.top, avatarImageName == nil ? 34 : 50)
            .padding(.bottom, 24)
            .padding(.horizontal, 20)
            .background(
                SpeechBubbleShape(
                    tailInset: avatarImageName == nil ? 80 : 225
                )
                .fill(Self.fillColor)
                .shadow(
                    color: Self.shadowColor,
                    radius: 0,
                    x: 2,
                    y: 7
                )
            )
            .overlay(alignment: .bottomTrailing) {
                DialogueAdvanceIndicator()
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topLeading) {
                if let avatarImageName {
                    Image(avatarImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.avatarWidth)
                        .offset(x: -30, y: -60)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .animation(.default, value: text)
    }
}

/// Shared Figma-style affordance for every tappable dialogue bubble.
struct DialogueAdvanceIndicator: View {
    private static let fill = Color(red: 210 / 255, green: 239 / 255, blue: 241 / 255)
    private static let ink = Color(red: 35 / 255, green: 85 / 255, blue: 99 / 255)

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Self.ink)
            .offset(x: 1)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Self.fill))
            .overlay(Circle().stroke(Self.ink, lineWidth: 2))
    }
}

/// Rounded rectangle with a small triangular tail on the top
private struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 20

    // Ekor tetap lancip
    var tailWidth: CGFloat = 16
    var tailHeight: CGFloat = 18
    var tailInset: CGFloat = 80

    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY + tailHeight, width: rect.width, height: rect.height - tailHeight)
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)

        let tailBaseLeft = CGPoint(x: bubbleRect.minX + tailInset, y: bubbleRect.minY)
        let tailBaseRight = CGPoint(x: bubbleRect.minX + tailInset + tailWidth, y: bubbleRect.minY)
        let tailTip = CGPoint(x: bubbleRect.minX + tailInset + tailWidth * 0.4, y: rect.minY)

        path.move(to: tailTip)
        path.addLine(to: tailBaseLeft)
        path.addLine(to: tailBaseRight)
        path.closeSubpath()

        return path
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack(spacing: 40) {
            Spacer()
            SpeechBubbleView(text: "Contoh teks bubble")
            // Realistic width + the real avatar combination — the short line above alone doesn't
            // catch tailInset overflowing a too-narrow bubble, so this is the one that actually
            // matches production usage (StoryBubbleSequence's ant-dialogue beats).

        }
        .padding(.horizontal, 20)
    }
}
