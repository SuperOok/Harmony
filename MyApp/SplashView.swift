import SwiftUI

/// The start: the app icon assembling itself. Six petals of stones fly out
/// of the centre one after another, clockwise from the top, each from the
/// inside out; the centre settles last, the flower breathes once, and the
/// whole thing fades into the app. The geometry lives in `IconFlower`, so
/// the last frame is the icon the tap came from.
struct SplashView: View {
    /// Called once the splash has faded out, or was tapped away.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var leaving = false
    @State private var titleVisible = false

    // Timing, in seconds from the start. The petals' own is in `IconFlower`.
    private static let breathAt = 1.55
    private static let breath = 0.5
    private static let leaveAt = 2.05
    private static let fade = 0.35

    var body: some View {
        ZStack {
            IconFlower.background.ignoresSafeArea()

            VStack(spacing: 28) {
                TimelineView(.animation(paused: leaving)) { timeline in
                    let t = reduceMotion ? 10 : timeline.date.timeIntervalSince(start)
                    // Once everything is down, the flower breathes once.
                    let breathing = t > Self.breathAt
                        ? 1 + 0.035 * sin(.pi * min(1, (t - Self.breathAt) / Self.breath))
                        : 1
                    Canvas { context, size in
                        IconFlower.draw(in: &context, size: size, at: t, breathing: breathing)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 360)

                Text("Harmony")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(IconFlower.centre)
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
                try? await Task.sleep(for: .seconds(IconFlower.centreAt + 0.15))
                withAnimation(.easeOut(duration: 0.45)) { titleVisible = true }
                try? await Task.sleep(for: .seconds(Self.leaveAt - IconFlower.centreAt - 0.15))
            }
            leave()
        }
    }

    private func leave() {
        guard !leaving else { return }
        withAnimation(.easeIn(duration: Self.fade)) { leaving = true } completion: {
            onFinished()
        }
    }
}

#Preview {
    SplashView {}
}
