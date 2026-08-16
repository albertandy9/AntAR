//
//  RingPatternTexture.swift
//  AntAR
//
//  Procedural ring-pattern tile — plain orange circle outlines on white, generated in code instead
//  of shipped as an asset so it can tile at any scale. Circles sit on a fixed grid, capped well
//  inside each tile's bounds (never touching the edge), which is what makes the tile seamless.
//

import CoreGraphics
import UIKit

enum RingPatternTexture {
    private static let tileSize: CGFloat = 128
    private static let spacing: CGFloat = 32
    private static let ringColor = UIColor.orange

    static var image: CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: tileSize, height: tileSize))
        let uiImage = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: tileSize, height: tileSize))

            context.setStrokeColor(ringColor.cgColor)
            context.setLineWidth(2)

            var y = spacing / 2
            while y < tileSize {
                var x = spacing / 2
                while x < tileSize {
                    // Capped well under spacing/2 so no circle ever crosses into the next tile.
                    let radius = spacing * 0.32
                    context.strokeEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    x += spacing
                }
                y += spacing
            }
        }
        guard let cgImage = uiImage.cgImage else {
            preconditionFailure("UIGraphicsImageRenderer always produces a backing CGImage")
        }
        return cgImage
    }
}
