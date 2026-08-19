//
//  ScanningTableView.swift
//  AntAR
//
//  Created by Albert Tandy Harison on 12/08/26.
//
//  Centered in the AR view: orange bracket-corner viewfinder + caption pill for plane finding
//  (isReadyToPlace/isSurfaceTooSmall drive the caption/tap-prompt — see caption below for the
//  three-state priority order).
//

import SwiftUI

struct ScanningTableView: View {
    let isReadyToPlace: Bool
    // True once ARKit has found a .table-classified plane that's still under the real
    // (0.80×0.80m) size requirement — distinct from "haven't found a table at all yet," so the
    // user gets told to look for a bigger surface instead of the generic "aim at a surface" hint.
    let isSurfaceTooSmall: Bool
    let surfaceDistanceStatus: SurfaceDistanceStatus

    // Design spec (Figma dev-mode, "Rectangle 19"): 222x222, corner radius 28, border 6 — applied
    // to the bracket geometry below (corner arc radius + stroke width), not a closed rectangle.
    // reticleSize is `static`, not private — LostAntDialogueView reserves the same invisible space
    // below its own caption so that caption lands at the exact same screen position as this view's.
    static let reticleSize: CGFloat = 222
    private let cornerRadius: CGFloat = 28
    private let borderWidth: CGFloat = 6
    private let cornerLength: CGFloat = 44

    private var caption: String {
        if isReadyToPlace {
            "Bidang datar terdeteksi"
        } else if isSurfaceTooSmall {
            "Cari bidang datar minimal 80 × 80 cm"
        } else if surfaceDistanceStatus == .tooClose {
            "Mundurkan ponsel hingga sekitar 80 cm"
        } else if surfaceDistanceStatus == .tooFar {
            "Dekatkan ponsel hingga sekitar 80 cm"
        } else {
            "Arahkan kamera ke bidang datar"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            CaptionPill(text: caption)

            BracketReticle(cornerLength: cornerLength, cornerRadius: cornerRadius)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: borderWidth, lineCap: .round))
                .frame(width: Self.reticleSize, height: Self.reticleSize)

            if isReadyToPlace {
                Text("Tap untuk Memindai")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.default, value: isReadyToPlace)
        .animation(.default, value: isSurfaceTooSmall)
    }
}


private struct BracketReticle: Shape {
    var cornerLength: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack {
            ScanningTableView(
                isReadyToPlace: false,
                isSurfaceTooSmall: false,
                surfaceDistanceStatus: .unavailable
            )
            Spacer().frame(height: 40)
            ScanningTableView(
                isReadyToPlace: false,
                isSurfaceTooSmall: true,
                surfaceDistanceStatus: .unavailable
            )
            Spacer().frame(height: 40)
            ScanningTableView(
                isReadyToPlace: true,
                isSurfaceTooSmall: false,
                surfaceDistanceStatus: .valid
            )
        }
    }
}
