//
//  UFODirectionIndicatorView.swift
//  AntAR
//


import SwiftUI

struct UFODirectionIndicatorView: View {
    /// Screen-space direction toward the UFO (x: right+, y: down+), arbitrary non-zero length —
    /// only the direction matters, ARExperienceViewModel.refreshUFODirectionIndicator() doesn't
    /// normalize it.
    let direction: CGVector

    private static let circleDiameter: CGFloat = 84
    private static let pointerLength: CGFloat = 22
    private static let pointerWidth: CGFloat = 26
    // Square big enough to contain the circle plus the pointer poking out in ANY rotated
    // direction, centered on the circle's own center — see clampedCenter(in:) for why that
    // symmetry matters (keeps the circle's position stable under rotation).
    private static let badgeFrameSide = circleDiameter + pointerLength * 2
    private static let edgeMargin: CGFloat = 16
    // Flat downward nudge on the whole badge, every direction, not just when pointing up — the
    // Dynamic Island was covering it regardless of which way it was pointing.
    private static let verticalShift: CGFloat = 90
    private static let backgroundColor = Color(red: 254 / 255, green: 245 / 255, blue: 237 / 255)

    var body: some View {
        GeometryReader { proxy in
            let angle = atan2(direction.dy, direction.dx)

            ZStack {
                DirectionalPinShape(
                    circleDiameter: Self.circleDiameter,
                    pointerLength: Self.pointerLength,
                    pointerWidth: Self.pointerWidth
                )
                .fill(Self.backgroundColor)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 4)
                .frame(width: Self.badgeFrameSide, height: Self.badgeFrameSide)
                // Default shape points "up" (12 o'clock); +90° maps that to angle's own
                // convention (0 = right), so the tip ends up aligned with `angle`.
                .rotationEffect(.radians(angle + .pi / 2))

                Image("vector_ufo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.circleDiameter * 0.62, height: Self.circleDiameter * 0.62)
            }
            .position(clampedCenter(in: proxy.size))
            .offset(y: Self.verticalShift)
        }
        .allowsHitTesting(false)
    }


    private func clampedCenter(in size: CGSize) -> CGPoint {
        let halfW = max(size.width / 2 - Self.badgeFrameSide / 2 - Self.edgeMargin, 1)
        let halfH = max(size.height / 2 - Self.badgeFrameSide / 2 - Self.edgeMargin, 1)

        let dx = abs(direction.dx) < 0.0001 ? 0.0001 : direction.dx
        let dy = abs(direction.dy) < 0.0001 ? 0.0001 : direction.dy
        let scale = min(halfW / abs(dx), halfH / abs(dy))

        return CGPoint(x: size.width / 2 + dx * scale, y: size.height / 2 + dy * scale)
    }
}


private struct DirectionalPinShape: Shape {
    var circleDiameter: CGFloat
    var pointerLength: CGFloat
    var pointerWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = circleDiameter / 2

        var path = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: circleDiameter, height: circleDiameter
        ))

        // baseY sits slightly inside the circle (not exactly on its edge) so the triangle's base
        // overlaps the circle instead of just touching it tangentially, avoiding a hairline seam.
        let baseY = center.y - radius + 4
        let tip = CGPoint(x: center.x, y: center.y - radius - pointerLength)
        let baseLeft = CGPoint(x: center.x - pointerWidth / 2, y: baseY)
        let baseRight = CGPoint(x: center.x + pointerWidth / 2, y: baseY)

        path.move(to: tip)
        path.addLine(to: baseRight)
        path.addLine(to: baseLeft)
        path.closeSubpath()

        return path
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        UFODirectionIndicatorView(direction: CGVector(dx: 1, dy: -0.4))
    }
}
