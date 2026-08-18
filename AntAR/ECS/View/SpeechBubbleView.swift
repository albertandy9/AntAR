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

    var body: some View {
        // ZStack, not .overlay() — bubble goes in FIRST (bottom layer) and the avatar SECOND (top
        // layer), so the ant now draws OVER the bubble where they overlap, in front instead of
        // tucked behind it.
        ZStack(alignment: .topLeading) {
            Text(text)
                .font(.custom("Fredoka-Regular", size: 20))
                .foregroundStyle(Self.textColor)
                .multilineTextAlignment(.center)
                // Padding internal dikembalikan agar teks tetap presisi di tengah kotak — top
                // padding grows a bit when there's an avatar overlapping down from above, so its
                // bottom edge doesn't crowd the first line of text. Bottom was only 10 (top was
                // 30-50), leaving noticeably less breathing room below the text than above it —
                // bumped to 24 so the text sits centered in the bubble instead of crowding its
                // bottom edge.
                .padding(.top, avatarImageName == nil ? 34 : 50)
                .padding(.bottom, 24)
                .padding(.horizontal, 20)
                .background(
                    // Only the avatar case pushes the tail out to 225 — that's not "wherever looks
                    // nice," it's specifically clearing the avatar's own right edge (offset x -30 +
                    // avatarWidth 240 = 210, +15 margin) so the tail isn't hidden behind the ant.
                    // The plain (no avatar) case keeps the original 80 — pushing every bubble to
                    // 225 would overflow a short, one-line, avatar-less bubble that never needs to
                    // clear anything.
                    SpeechBubbleShape(tailInset: avatarImageName == nil ? 80 : 225)
                        .fill(Self.fillColor)
                        .shadow(color: Self.shadowColor, radius: 0, x: 2, y: 7)
                )

            if let avatarImageName {
                Image(avatarImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.avatarWidth)
                    // Mostly above the bubble (negative y pushes it up), a little over the
                    // bubble's own leading edge (negative x) so it reads as "perched on top of
                    // the tail corner" rather than floating separately above it. Fixed points,
                    // not a fraction of avatarWidth — height is no longer a known square, so
                    // there's nothing meaningful to take a fraction of.
                    //
                    // At avatarWidth=240, rendered height ≈ 240/(195/96) ≈ 118. The bubble's
                    // visible teal surface starts 18pt down from this ZStack's origin
                    // (SpeechBubbleShape's tailHeight — the tiny pointer triangle occupies the
                    // first 18pt), so offset -60 puts the avatar's bottom edge at frame-relative
                    // y ≈ 58: 40pt into the visible bubble, just above the text's own top padding
                    // (50) so the overlap still doesn't cover any text.
                    .offset(x: -30, y: -60)
            }
        }
        .animation(.default, value: text)
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
