import SwiftUI

/// Where the squirrel's animation stands and the camera frames, written by
/// `tools/szenen/export.py` (`animate.anchors` there).
struct SquirrelAnchors {
    let ridgeMid, ridgeBack, perch, start: CGPoint
    let crownPath: [CGPoint]
    let close, wide, habitat: CGRect

    init(_ a: SceneDisplayList.AnchorsDTO) {
        func rect(_ v: [Double]) -> CGRect { CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }
        ridgeMid = CGPoint(a.ridge_mid)
        ridgeBack = CGPoint(a.ridge_back)
        perch = CGPoint(a.perch)
        start = CGPoint(a.start)
        crownPath = a.crown_path.map(CGPoint.init)
        close = rect(a.close)
        wide = rect(a.wide)
        habitat = rect(a.habitat)
    }
}

/// How the squirrel and the camera stand at one moment.
struct SquirrelPose {
    var feet = CGPoint.zero
    /// 1 faces right, -1 left.
    var face = 1.0
    /// Squash and stretch.
    var sx = 1.0, sy = 1.0
    /// How far the nut is lifted towards the mouth.
    var nut = CGPoint.zero
    /// The tail's swing, in degrees.
    var tail = 0.0
    /// 1 open, small for a blink.
    var blink = 1.0
    var alpha = 1.0
    var airborne = false
    /// The camera: the part of the scene on screen, 430 : 932 like a phone.
    var view = CGRect.zero
}

/// The first animation, as `tools/szenen/animate.py` has it (that file
/// states the story): the camera starts close on the tree's crown, the
/// squirrel jumps in, the camera pulls back, it runs across the crown,
/// leaps down onto the roof, runs down the ridge and settles on its house
/// to nibble its nut, and the camera pulls back a second time to show the
/// habitat. Same numbers as there, so a change in one goes into the other.
struct SquirrelTimeline {
    let anchors: SquirrelAnchors

    /// Seconds. The Python version fades the squirrel out here and starts
    /// again; the app fades the whole picture instead.
    static let length = 13.5

    func pose(at t: Double) -> SquirrelPose {
        let a = anchors
        var p = SquirrelPose(view: a.close)
        func ease(_ u: Double) -> Double { u * u * (3 - 2 * u) }
        func lerp(_ x: Double, _ y: Double, _ u: Double) -> Double { x + (y - x) * u }
        func lerp(_ x: CGPoint, _ y: CGPoint, _ u: Double) -> CGPoint {
            CGPoint(x: lerp(x.x, y.x, u), y: lerp(x.y, y.y, u))
        }
        func lerp(_ x: CGRect, _ y: CGRect, _ u: Double) -> CGRect {
            CGRect(x: lerp(x.minX, y.minX, u), y: lerp(x.minY, y.minY, u),
                   width: lerp(x.width, y.width, u), height: lerp(x.height, y.height, u))
        }
        func jump(_ from: CGPoint, _ to: CGPoint, _ u: Double, _ height: Double) -> CGPoint {
            let q = lerp(from, to, u)
            return CGPoint(x: q.x, y: q.y - height * 4 * u * (1 - u))
        }
        /// A short squash on landing and the like, 0 → 1 → 0.
        func squash(_ x: Double) -> Double { sin(.pi * x) }

        let crown = a.crownPath
        let crownEnd = crown[crown.count - 1]

        if t < 0.4 {                                  // the empty crown
            p.feet = a.start
            p.alpha = 0
        } else if t < 1.2 {                           // jumps in from the left onto the crown
            let u = (t - 0.4) / 0.8
            p.feet = jump(a.start, a.perch, ease(u), 5)
            p.airborne = 0.1 < u && u < 0.95
            if p.airborne { p.sx = 0.92; p.sy = 1.1 }
            p.alpha = min(1, (t - 0.4) / 0.15)
        } else if t < 1.45 {                          // lands: squash and back
            p.feet = a.perch
            let sq = squash((t - 1.2) / 0.25)
            p.sx = 1 + 0.14 * sq
            p.sy = 1 - 0.16 * sq
        } else if t < 2.6 {                           // stops, looks, blinks, flicks its tail
            p.feet = a.perch
            p.tail = 8 * sin((t - 1.45) * 7) * exp(-(t - 1.45) * 1.5)
            p.blink = 2.0 < t && t < 2.12 ? 0.1 : 1
        } else if t < 4.2 {                           // the camera pulls back: there is the house
            p.feet = a.perch
            p.view = lerp(a.close, a.wide, ease((t - 2.6) / 1.6))
            p.tail = 3 * sin((t - 2.6) * 4)
        } else if t < 5.8 {                           // runs across the crown from clump to clump
            p.view = a.wide
            let u = (t - 4.2) / 1.6 * Double(crown.count - 1)
            let k = min(Int(u), crown.count - 2)
            let v = u - Double(k)
            let hop = abs(sin(v * .pi * 2))
            let q = lerp(crown[k], crown[k + 1], v)
            p.feet = CGPoint(x: q.x, y: q.y - 0.9 * hop)
            p.sx = 1 + 0.06 * (1 - hop)
            p.sy = 1 - 0.06 * (1 - hop)
            p.tail = 10 * hop
        } else if t < 6.05 {                          // crouches at the edge of the crown, turns to the roof
            p.view = a.wide
            p.feet = crownEnd
            p.face = -1
            let sq = sin(.pi * (t - 5.8) / 0.25 * 0.5)
            p.sx = 1 + 0.12 * sq
            p.sy = 1 - 0.18 * sq
        } else if t < 6.85 {                          // leaps down onto the back of the roof
            p.view = a.wide
            p.face = -1
            p.feet = jump(crownEnd, a.ridgeBack, ease((t - 6.05) / 0.8), 4)
            p.sx = 0.9
            p.sy = 1.12
            p.tail = -12
            p.airborne = true
        } else if t < 7.15 {                          // lands on the ridge
            p.view = a.wide
            p.face = -1
            p.feet = a.ridgeBack
            let sq = squash((t - 6.85) / 0.3)
            p.sx = 1 + 0.16 * sq
            p.sy = 1 - 0.18 * sq
        } else if t < 8.0 {                           // runs down the ridge in little hops
            p.view = a.wide
            p.face = -1
            let u = (t - 7.15) / 0.85
            let q = lerp(a.ridgeBack, a.ridgeMid, u)
            let hop = abs(sin(u * .pi * 3))
            p.feet = CGPoint(x: q.x, y: q.y - 0.7 * hop)
            p.sx = 1 + 0.06 * (1 - hop)
            p.sy = 1 - 0.06 * (1 - hop)
            p.tail = 10 * hop
        } else {                                      // turns round on its house, settles and nibbles
            p.feet = a.ridgeMid
            p.view = lerp(a.wide, a.habitat, ease(min(1, max(0, (t - 9.0) / 2.2))))
            p.face = t > 8.3 ? 1 : -1
            p.tail = 4 * sin((t - 8.0) * 2.2)
            let n = t - 8.7
            if n > 0 {
                let lift = min(1, n / 0.35)
                let nibble = n > 0.35 ? 0.9 * abs(sin(n * 14)) : 0
                p.nut = CGPoint(x: -1.5 * lift, y: -6 * lift + nibble)
            }
            p.blink = 10.5 < t && t < 10.62 ? 0.1 : 1
        }
        return p
    }
}
