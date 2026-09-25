import SwiftUI
import HarmonyRules

/// The flower of the app icon: six petals of stones around a small centre.
///
/// The geometry is the icon's, taken from `tools/app-icon.swift` — same
/// design units, same petal order, same colours — and shared by the splash,
/// which lets it assemble, and the start screen, which shows it still.
enum IconFlower {
    /// The icon's background: the splash's, the start screen's and the
    /// launch screen's (`LaunchBackground` in the asset catalogue).
    static let background = Color(red: 0.133, green: 0.192, blue: 0.227)
    /// The light stone in the middle, and the colour of the name.
    static let centre = Color(red: 0.95, green: 0.93, blue: 0.86)

    /// Petal order, clockwise from the top.
    static let petals: [Stone] = [.water, .leaves, .field, .brick, .wood, .stone]

    struct Dot {
        let point: CGPoint
        let colour: Color
        /// When it sets off in the splash, in seconds.
        let delay: Double
    }

    // Timing of the splash, in seconds from its start.
    static let petalStagger = 0.11
    static let ringStagger = 0.07
    static let flight = 0.42
    static let centreAt = 0.9

    // Design units, as in the icon: 100 × 100.
    private static let petalDistance: CGFloat = 23
    private static let spacing: CGFloat = 4.6
    static let dotRadius: CGFloat = 1.95

    private static func petalAngle(_ i: Int) -> CGFloat { -.pi / 2 + CGFloat(i) * .pi / 3 }

    /// Every dot of the icon, with when it sets off: petals one after the
    /// other, and inside a petal ring by ring from its middle.
    static let dots: [Dot] = {
        var result: [Dot] = []
        for (i, stone) in petals.enumerated() {
            let a = petalAngle(i)
            let cx = 50 + petalDistance * cos(a)
            let cy = 50 + petalDistance * sin(a)
            for q in -2...2 {
                for r in -2...2 where abs(q + r) <= 2 {
                    let ring = max(abs(q), abs(r), abs(q + r))
                    let x = spacing * (CGFloat(q) + CGFloat(r) / 2)
                    let y = spacing * CGFloat(r) * 0.866
                    result.append(Dot(point: CGPoint(x: cx - y, y: cy + x),
                                      colour: stone.color,
                                      delay: Double(i) * petalStagger + Double(ring) * ringStagger))
                }
            }
        }
        // The centre: its six stones, then the light one in the middle.
        for (i, stone) in petals.enumerated() {
            let a = petalAngle(i)
            result.append(Dot(point: CGPoint(x: 50 + spacing * cos(a), y: 50 + spacing * sin(a)),
                              colour: stone.color,
                              delay: centreAt + Double(i) * 0.03))
        }
        result.append(Dot(point: CGPoint(x: 50, y: 50), colour: centre, delay: centreAt + 0.2))
        return result
    }()

    /// One frame, `t` seconds into the splash. Every dot flies from the
    /// centre to its place and grows as it goes, overshooting a little, so
    /// the petal lands rather than appears. Far enough into it, this is the
    /// icon standing still.
    static func draw(in context: inout GraphicsContext, size: CGSize,
                     at t: Double, breathing: Double = 1) {
        let scale = min(size.width, size.height) / 100
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: scale * breathing, y: scale * breathing)
        context.translateBy(x: -50, y: -50)

        let origin = CGPoint(x: 50, y: 50)
        for dot in dots {
            let p = max(0, min(1, (t - dot.delay) / flight))
            guard p > 0 else { continue }
            let travel = easeOutCubic(p)
            let grow = easeOutBack(p)
            let x = origin.x + (dot.point.x - origin.x) * travel
            let y = origin.y + (dot.point.y - origin.y) * travel
            let r = dotRadius * grow
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                         with: .color(dot.colour.opacity(min(1, p * 2.5))))
        }
    }

    private static func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    /// Past one and back: the little overshoot of something set down.
    private static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

/// The flower standing still, as on the start screen. The design units
/// leave a margin round the petals, as the icon does; the frame should
/// allow for it.
struct IconFlowerView: View {
    var body: some View {
        Canvas { context, size in
            IconFlower.draw(in: &context, size: size, at: .greatestFiniteMagnitude)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
