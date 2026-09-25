import SwiftUI
import HarmonyRules

/// The start: the app icon assembling itself. Six petals of stones fly out
/// of the centre one after another, clockwise from the top, each from the
/// inside out; the centre settles last, the flower breathes once, and the
/// whole thing fades into the app.
///
/// The geometry is the icon's, taken from `tools/app-icon.swift` — same
/// design units, same petal order, same colours — so the last frame is the
/// icon the tap came from.
struct SplashView: View {
    /// Called once the splash has faded out, or was tapped away.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var leaving = false

    /// The icon's background, and the launch screen's.
    static let background = Color(red: 0.133, green: 0.192, blue: 0.227)
    private static let centre = Color(red: 0.95, green: 0.93, blue: 0.86)

    /// Petal order, clockwise from the top.
    private static let petals: [Stone] = [.water, .leaves, .field, .brick, .wood, .stone]

    // Timing, in seconds from the start.
    private static let petalStagger = 0.11
    private static let ringStagger = 0.07
    private static let flight = 0.42
    private static let centreAt = 0.9
    private static let breathAt = 1.55
    private static let breath = 0.5
    private static let leaveAt = 2.05
    private static let fade = 0.35

    var body: some View {
        ZStack {
            Self.background.ignoresSafeArea()

            VStack(spacing: 28) {
                TimelineView(.animation(paused: leaving)) { timeline in
                    let t = reduceMotion ? 10 : timeline.date.timeIntervalSince(start)
                    Canvas { context, size in
                        draw(in: &context, size: size, at: t)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 360)

                Text("Harmony")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Self.centre)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 8)
            }
            .padding(.horizontal, 32)
        }
        .opacity(leaving ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { leave() }
        .accessibilityElement()
        .accessibilityLabel("Harmony")
        .task {
            start = .now
            if reduceMotion {
                titleVisible = true
                try? await Task.sleep(for: .seconds(0.8))
            } else {
                try? await Task.sleep(for: .seconds(Self.centreAt + 0.15))
                withAnimation(.easeOut(duration: 0.45)) { titleVisible = true }
                try? await Task.sleep(for: .seconds(Self.leaveAt - Self.centreAt - 0.15))
            }
            leave()
        }
    }

    @State private var titleVisible = false

    private func leave() {
        guard !leaving else { return }
        withAnimation(.easeIn(duration: Self.fade)) { leaving = true } completion: {
            onFinished()
        }
    }

    // MARK: - Drawing

    /// One frame. Every dot flies from the centre to its place and grows as
    /// it goes, overshooting a little, so the petal lands rather than
    /// appears.
    private func draw(in context: inout GraphicsContext, size: CGSize, at t: Double) {
        let scale = min(size.width, size.height) / 100
        // Once everything is down, the flower breathes once.
        let breathing = t > Self.breathAt
            ? 1 + 0.035 * sin(.pi * min(1, (t - Self.breathAt) / Self.breath))
            : 1
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: scale * breathing, y: scale * breathing)
        context.translateBy(x: -50, y: -50)

        let origin = CGPoint(x: 50, y: 50)
        for dot in Self.dots {
            let p = Self.progress(t - dot.delay)
            guard p > 0 else { continue }
            let travel = Self.easeOutCubic(p)
            let grow = Self.easeOutBack(p)
            let x = origin.x + (dot.point.x - origin.x) * travel
            let y = origin.y + (dot.point.y - origin.y) * travel
            let r = Self.dotRadius * grow
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                         with: .color(dot.colour.opacity(min(1, p * 2.5))))
        }
    }

    private static func progress(_ elapsed: Double) -> Double {
        max(0, min(1, elapsed / flight))
    }

    private static func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    /// Past one and back: the little overshoot of something set down.
    private static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    // MARK: - The icon's geometry

    private struct Dot {
        let point: CGPoint
        let colour: Color
        let delay: Double
    }

    // Design units, as in the icon: 100 × 100.
    private static let petalDistance: CGFloat = 23
    private static let spacing: CGFloat = 4.6
    private static let dotRadius: CGFloat = 1.95

    private static func petalAngle(_ i: Int) -> CGFloat { -.pi / 2 + CGFloat(i) * .pi / 3 }

    /// Every dot of the icon, with when it sets off: petals one after the
    /// other, and inside a petal ring by ring from its middle.
    private static let dots: [Dot] = {
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
}

#Preview {
    SplashView {}
}
