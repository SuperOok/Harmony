// Draws the app icon: six hexagons of small dots, one per stone colour,
// arranged in a ring. Run from the repository root:
//
//     swift tools/app-icon.swift
//
// Writes the plain and the tinted variant into the AppIcon asset set.
// The colours are those of `Stone.color` in MyApp/Dummy/SampleData.swift.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

typealias RGB = (r: CGFloat, g: CGFloat, b: CGFloat)

// Petal order, clockwise from the top.
let stones: [RGB] = [
    (0.20, 0.47, 0.75),  // water
    (0.25, 0.56, 0.29),  // leaves
    (0.93, 0.78, 0.22),  // field
    (0.78, 0.26, 0.22),  // brick
    (0.45, 0.31, 0.19),  // wood
    (0.55, 0.55, 0.55),  // stone
]
let background: RGB = (0.133, 0.192, 0.227)
let centre: RGB = (0.95, 0.93, 0.86)

// Design units: the icon is 100 × 100.
let petalDistance: CGFloat = 23
let spacing: CGFloat = 4.6
let dotRadius: CGFloat = 1.95

/// Dot positions of a hexagon of `rings` rings around (cx, cy). The grid is
/// turned so that a dot's six neighbours lie at -90°, -30°, 30°, … — the
/// same directions as the petals.
func hexagon(_ cx: CGFloat, _ cy: CGFloat, rings: Int) -> [CGPoint] {
    var points: [CGPoint] = []
    for q in -rings...rings {
        for r in -rings...rings where abs(q + r) <= rings {
            let x = spacing * (CGFloat(q) + CGFloat(r) / 2)
            let y = spacing * CGFloat(r) * 0.866
            points.append(CGPoint(x: cx - y, y: cy + x))
        }
    }
    return points
}

func petalAngle(_ i: Int) -> CGFloat { -.pi / 2 + CGFloat(i) * .pi / 3 }

func dots() -> [(CGPoint, RGB)] {
    var result: [(CGPoint, RGB)] = []
    for (i, colour) in stones.enumerated() {
        let a = petalAngle(i)
        for p in hexagon(50 + petalDistance * cos(a), 50 + petalDistance * sin(a), rings: 2) {
            result.append((p, colour))
        }
    }
    // The centre: one light dot, each neighbour in the colour of the petal it faces.
    result.append((CGPoint(x: 50, y: 50), centre))
    for (i, colour) in stones.enumerated() {
        let a = petalAngle(i)
        result.append((CGPoint(x: 50 + spacing * cos(a), y: 50 + spacing * sin(a)), colour))
    }
    return result
}

func luminance(_ c: RGB) -> CGFloat { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

func render(to url: URL, tinted: Bool) {
    let size = 1024
    let scale = CGFloat(size) / 100
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // y grows downwards, as in the design.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)

    // The tinted variant is greyscale on black; the system applies the tint.
    let bg: RGB = tinted ? (0, 0, 0) : background
    ctx.setFillColor(red: bg.r, green: bg.g, blue: bg.b, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

    for (p, c) in dots() {
        let colour: RGB
        if tinted {
            // Lift the dark stones so every petal stays visible.
            let l = 0.35 + 0.65 * luminance(c)
            colour = (l, l, l)
        } else {
            colour = c
        }
        ctx.setFillColor(red: colour.r, green: colour.g, blue: colour.b, alpha: 1)
        ctx.fillEllipse(in: CGRect(x: p.x - dotRadius, y: p.y - dotRadius,
                                   width: 2 * dotRadius, height: 2 * dotRadius))
    }

    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

let dir = URL(fileURLWithPath: "MyApp/Assets.xcassets/AppIcon.appiconset")
render(to: dir.appendingPathComponent("AppIcon.png"), tinted: false)
render(to: dir.appendingPathComponent("AppIcon-tinted.png"), tinted: true)
