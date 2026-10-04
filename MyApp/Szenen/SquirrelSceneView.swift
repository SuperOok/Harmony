import SwiftUI

/// The squirrel's first animation, full screen: the scene from the display
/// list, the squirrel on top, the camera from `SquirrelTimeline`. Played
/// before the About screen. A tap ends it early.
struct SquirrelSceneView: View {
    /// Called when the picture starts to fade out, so that what lies behind
    /// it can be put in place.
    var onLeaving: () -> Void = {}
    /// Called once it has faded out.
    var onFinished: () -> Void

    @State private var start = Date.now
    @State private var leaving = false

    private static let fade = 0.5
    private static let quickFade = 0.3

    var body: some View {
        ZStack {
            IconFlower.background.ignoresSafeArea()
            if let list = SceneDisplayList.squirrelHabitat {
                let timeline = SquirrelTimeline(anchors: list.anchors)
                TimelineView(.animation(paused: leaving)) { clock in
                    let t = clock.date.timeIntervalSince(start)
                    Canvas { context, size in
                        SceneRenderer.draw(list, pose: timeline.pose(at: min(t, SquirrelTimeline.length)),
                                           in: &context, size: size)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .opacity(leaving ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { leave(Self.quickFade) }
        .accessibilityElement()
        .accessibilityLabel("Ein Eichhörnchen läuft über die Bäume zu seinem Haus")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("squirrel-scene")
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(SquirrelTimeline.length - Self.fade))
            leave(Self.fade)
        }
    }

    private func leave(_ duration: Double) {
        guard !leaving else { return }
        onLeaving()
        withAnimation(.easeIn(duration: duration)) { leaving = true } completion: {
            onFinished()
        }
    }
}

enum SceneRenderer {
    /// The warm brown of cast shadows, `SHADOW_COLOUR` in `tools/szenen/style.py`.
    static let shadowColour = Color(hex: "#3A2813")

    /// One frame. The camera shows `pose.view`, a phone-shaped part of the
    /// scene, as large as fits; a wider screen shows more to the sides.
    static func draw(_ list: SceneDisplayList, pose: SquirrelPose,
                     in context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(list.background))

        let frame = pose.view
        let scale = min(size.width / frame.width, size.height / frame.height)
        let camera = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -frame.midX, y: -frame.midY)
        var c = context
        c.concatenate(camera)
        let visible = CGRect(origin: .zero, size: size).applying(camera.inverted()).insetBy(dx: -1, dy: -1)

        for node in list.scene { node.draw(in: &c, visible: visible) }
        drawSquirrel(list.squirrel, pose: pose, in: &c, visible: visible)
    }

    private static func drawSquirrel(_ s: SceneDisplayList.Squirrel, pose: SquirrelPose,
                                     in context: inout GraphicsContext, visible: CGRect) {
        guard pose.alpha > 0 else { return }
        var c = context
        let feet = pose.feet

        // The shadow under its feet, gone while it is in the air.
        if !pose.airborne {
            var shadow = c
            shadow.opacity = 0.3 * pose.alpha
            shadow.fill(Path(ellipseIn: CGRect(x: feet.x - 1.0, y: feet.y + 0.05 - 0.25, width: 2.0, height: 0.5)),
                        with: .color(SceneRenderer.shadowColour))
        }

        c.opacity = pose.alpha
        // translate(feet) scale(face·sx·k, sy·k) translate(-figure feet)
        c.concatenate(CGAffineTransform(translationX: -s.feet.x, y: -s.feet.y)
            .concatenating(CGAffineTransform(scaleX: pose.face * pose.sx * s.scale, y: pose.sy * s.scale))
            .concatenating(CGAffineTransform(translationX: feet.x, y: feet.y)))

        let moved: [String: CGAffineTransform] = [
            // rotate(angle, root) = translate(root) rotate translate(-root)
            "tail": CGAffineTransform(translationX: -s.tailRoot.x, y: -s.tailRoot.y)
                .concatenating(CGAffineTransform(rotationAngle: pose.tail * .pi / 180))
                .concatenating(CGAffineTransform(translationX: s.tailRoot.x, y: s.tailRoot.y)),
            "nut": CGAffineTransform(translationX: pose.nut.x, y: pose.nut.y),
            "eye": CGAffineTransform(scaleX: 1, y: pose.blink),
        ]
        for node in s.nodes { node.draw(in: &c, visible: nil, moved: moved) }
    }
}

#Preview {
    SquirrelSceneView {}
}
