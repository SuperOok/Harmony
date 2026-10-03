import SwiftUI

/// A scene as a display list: shapes in drawing order, written by
/// `tools/szenen/export.py` from the same Python code that draws the SVG
/// previews, and drawn here with `Canvas`.
///
/// The list holds only what stands still. What moves, the squirrel and the
/// camera, is computed by `SquirrelTimeline`; the squirrel's own list has
/// named groups (`tail`, `nut`, `eye`) the caller moves.
struct SceneDisplayList {
    /// The drawn area, in drawing units (100 wide for the widest framing).
    let view: CGRect
    let background: Color
    let scene: [SceneNode]
    let squirrel: Squirrel
    let anchors: SquirrelAnchors

    struct Squirrel {
        let nodes: [SceneNode]
        let scale: CGFloat
        let feet: CGPoint
        let tailRoot: CGPoint
        let eye: CGPoint
    }

    /// The first card's scene, loaded once. `nil` only if the file is
    /// missing from the bundle, which the splash cannot recover from.
    static let squirrelHabitat: SceneDisplayList? = load(named: "szene-eichhoernchen")

    static func load(named name: String, in bundle: Bundle = .main) -> SceneDisplayList? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { return nil }
        let gradients = file.gradients.mapValues { Fill($0) }
        func nodes(_ dtos: [NodeDTO]) -> [SceneNode] { dtos.map { SceneNode($0, gradients) } }
        return SceneDisplayList(
            view: CGRect(x: file.view[0], y: file.view[1], width: file.view[2], height: file.view[3]),
            background: Color(hex: file.background),
            scene: nodes(file.scene),
            squirrel: Squirrel(nodes: nodes(file.squirrel.ops),
                               scale: file.squirrel.scale,
                               feet: CGPoint(file.squirrel.feet),
                               tailRoot: CGPoint(file.squirrel.tailRoot),
                               eye: CGPoint(file.squirrel.eye)),
            anchors: SquirrelAnchors(file.anchors))
    }

    // MARK: The file

    private struct File: Decodable {
        let view: [Double]
        let background: String
        let gradients: [String: GradientDTO]
        let scene: [NodeDTO]
        let squirrel: SquirrelDTO
        let anchors: AnchorsDTO
    }

    private struct SquirrelDTO: Decodable {
        let ops: [NodeDTO]
        let scale: Double
        let feet: [Double]
        let tailRoot: [Double]
        let eye: [Double]
    }

    struct AnchorsDTO: Decodable {
        let ridge_mid: [Double]
        let ridge_back: [Double]
        let perch: [Double]
        let crown_path: [[Double]]
        let start: [Double]
        let close: [Double]
        let wide: [Double]
        let habitat: [Double]
    }
}

// MARK: - Nodes

/// Keys are short, the file is large.
struct NodeDTO: Decodable {
    var d: String?              // path: M, L, Q, C, Z
    var m: [Double]?            // matrix a b c d tx ty
    var f: String?              // fill: "#RRGGBB" or "@gradient"
    var fo: Double?
    var s: String?              // stroke
    var sw: Double?
    var so: Double?
    var cap: String?
    var join: String?
    var bb: [Double]?           // bounding box, for a gradient in box units
    var g: [NodeDTO]?           // children
    var clip: String?
    var id: String?             // a group the caller moves
}

struct GradientDTO: Decodable {
    let k: String               // "l" linear, "r" radial
    let u: Bool                 // in drawing units, not in box units
    let a: [Double]             // x1 y1 x2 y2, or cx cy r
    let s: [Stop]

    /// A row of the file: [offset, colour, opacity].
    struct Stop: Decodable {
        let offset: Double
        let colour: String
        let opacity: Double
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            offset = try c.decode(Double.self)
            colour = try c.decode(String.self)
            opacity = try c.decode(Double.self)
        }
    }
}

enum Fill {
    case colour(Color)
    /// `inBoxUnits`: the shading is laid out in the unit square of the
    /// shape's bounding box, the way SVG does for `objectBoundingBox`.
    case shading(GraphicsContext.Shading, inBoxUnits: Bool)

    init(_ g: GradientDTO) {
        let gradient = Gradient(stops: g.s.map {
            .init(color: Color(hex: $0.colour).opacity($0.opacity), location: $0.offset)
        })
        let shading: GraphicsContext.Shading = g.k == "l"
            ? .linearGradient(gradient, startPoint: CGPoint(x: g.a[0], y: g.a[1]), endPoint: CGPoint(x: g.a[2], y: g.a[3]))
            : .radialGradient(gradient, center: CGPoint(x: g.a[0], y: g.a[1]), startRadius: 0, endRadius: g.a[2])
        self = .shading(shading, inBoxUnits: !g.u)
    }
}

struct SceneNode {
    var path: Path?
    /// The path in the unit square of its bounding box, for a gradient.
    var unitPath: Path?
    var boxToUser: CGAffineTransform?
    var fill: Fill?
    var fillOpacity = 1.0
    var stroke: Color?
    var strokeStyle = StrokeStyle()
    var strokeOpacity = 1.0
    var transform: CGAffineTransform?
    var clip: Path?
    var id: String?
    var children: [SceneNode]?
    /// Where it can be seen, for skipping what is off the screen. `nil`
    /// when a transform inside makes that unknown.
    var bounds: CGRect?

    init(_ dto: NodeDTO, _ gradients: [String: Fill]) {
        id = dto.id
        transform = dto.m.map { CGAffineTransform(a: $0[0], b: $0[1], c: $0[2], d: $0[3], tx: $0[4], ty: $0[5]) }
        if let kids = dto.g {
            let nodes = kids.map { SceneNode($0, gradients) }
            children = nodes
            clip = dto.clip.map(Path.init(svg:))
            if transform == nil {
                bounds = clip?.boundingRect ?? nodes.reduce(CGRect.null) { acc, n in
                    guard let b = n.bounds else { return acc }
                    return acc.union(b)
                }
                if nodes.contains(where: { $0.bounds == nil }) { bounds = nil }
            }
            return
        }
        let p = Path(svg: dto.d ?? "")
        path = p
        if let f = dto.f {
            if f.hasPrefix("@"), let g = gradients[String(f.dropFirst())] {
                fill = g
                if case .shading(_, true) = g, let bb = dto.bb, bb[2] > 0, bb[3] > 0 {
                    let box = CGAffineTransform(a: bb[2], b: 0, c: 0, d: bb[3], tx: bb[0], ty: bb[1])
                    boxToUser = box
                    unitPath = p.applying(box.inverted())
                }
            } else {
                fill = .colour(Color(hex: f))
            }
            fillOpacity = dto.fo ?? 1
        }
        if let s = dto.s {
            stroke = Color(hex: s)
            strokeStyle = StrokeStyle(lineWidth: dto.sw ?? 1,
                                      lineCap: dto.cap == "round" ? .round : .butt,
                                      lineJoin: dto.join == "round" ? .round : .miter)
            strokeOpacity = dto.so ?? 1
        }
        if transform == nil {
            bounds = p.boundingRect.insetBy(dx: -strokeStyle.lineWidth, dy: -strokeStyle.lineWidth)
        }
    }

    /// Draws the node. `visible` is the area on screen in the node's own
    /// units; `moved` holds the matrices of the named groups.
    func draw(in context: inout GraphicsContext, visible: CGRect?, moved: [String: CGAffineTransform] = [:]) {
        if let visible, let bounds, !bounds.intersects(visible) { return }

        if let children {
            var c = context
            var inside = visible
            if let transform {
                c.concatenate(transform)
                inside = nil
            }
            if let id, let m = moved[id] {
                c.concatenate(m)
                inside = nil
            }
            if let clip { c.clip(to: clip) }
            for child in children { child.draw(in: &c, visible: inside, moved: moved) }
            return
        }

        guard let path else { return }
        var c = context
        if let transform { c.concatenate(transform) }
        switch fill {
        case .colour(let colour):
            c.fill(path, with: .color(colour.opacity(fillOpacity)))
        case .shading(let shading, let inBox):
            var g = c
            if fillOpacity != 1 { g.opacity *= fillOpacity }
            if inBox, let boxToUser, let unitPath {
                g.concatenate(boxToUser)
                g.fill(unitPath, with: shading)
            } else {
                g.fill(path, with: shading)
            }
        case nil:
            break
        }
        if let stroke {
            c.stroke(path, with: .color(stroke.opacity(strokeOpacity)), style: strokeStyle)
        }
    }
}

// MARK: - Parsing

extension Path {
    /// A path from `M x y L x y Q x1 y1 x y C x1 y1 x2 y2 x y Z`, the only
    /// commands the exporter writes.
    init(svg: String) {
        self.init()
        let tokens = svg.split(separator: " ")
        var i = 0
        func point() -> CGPoint {
            defer { i += 2 }
            return CGPoint(x: Double(tokens[i])!, y: Double(tokens[i + 1])!)
        }
        while i < tokens.count {
            let command = tokens[i]
            i += 1
            switch command {
            case "M": move(to: point())
            case "L": addLine(to: point())
            case "Q":
                let c = point()
                addQuadCurve(to: point(), control: c)
            case "C":
                let c1 = point(), c2 = point()
                addCurve(to: point(), control1: c1, control2: c2)
            case "Z": closeSubpath()
            default: break
            }
        }
    }
}

extension CGPoint {
    init(_ v: [Double]) { self.init(x: v[0], y: v[1]) }
}

extension Color {
    /// `#RRGGBB`.
    init(hex: String) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}
