//
//  LostAntChatBubbleView.swift
//  AntAR
//

import SwiftUI

/// Cycles through the ant's two dialogue lines, 2s each, starting 2s after LostAntGreetSystem enters
/// .releasing (see ContentView's .task(id:)) — together that fills the 6s releaseDuration exactly.
struct LostAntChatBubbleView: View {
    private static let lines = [
        "Aku tidak bisa pulang mengikuti rombongan karena antena ku copot",
        "Aku memerlukan antena ku untuk mendeteksi jalur perjalananku pulang"
    ]
    private static let lineDuration: Duration = .seconds(2)

    @State private var lineIndex = 0

    var body: some View {
        HStack {
            Spacer() // Mendorong balon dari kiri agar ke tengah
            SpeechBubble(text: Self.lines[lineIndex])
            Spacer() // Mendorong balon dari kanan
        }
        .padding(.horizontal, 15)
        // MENDONGKRAK BALON LEBIH NAIK:
        // Ubah angka 60 ini menjadi lebih besar (misal 80/100) jika masih kurang naik
        .padding(.bottom, 100)
        .task {
            lineIndex = 0
            for index in 1..<Self.lines.count {
                try? await Task.sleep(for: Self.lineDuration)
                lineIndex = index
            }
        }
    }
}

private struct SpeechBubble: View {
    let text: String

    private static let textColor = Color(red: 252/255, green: 226/255, blue: 201/255)   // #FCE2C9
    private static let fillColor = Color(red: 98/255, green: 165/255, blue: 183/255)    // #62A5B7
    private static let shadowColor = Color(red: 35/255, green: 85/255, blue: 99/255)    // #235563

    var body: some View {
        Text(text)
            .font(.custom("Fredoka-Regular", size: 20))
            .foregroundStyle(Self.textColor)
            .multilineTextAlignment(.center)
            // Padding internal dikembalikan agar teks tetap presisi di tengah kotak
            .padding(.top, 30)
            .padding(.bottom, 10)
            .padding(.horizontal, 20)
            .background(
                SpeechBubbleShape()
                    .fill(Self.fillColor)
                    .shadow(color: Self.shadowColor, radius: 0, x: 2, y: 7)
            )
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
        VStack {
            Spacer()
            LostAntChatBubbleView()
        }
    }
}
