import SwiftUI

/// Flat-top hexagon: corners left and right, edges top and bottom.
/// Fitted into a rectangle of width 2R and height √3·R.
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        var p = Path()
        for i in 0..<6 {
            let a = Double(i) * .pi / 3
            let point = CGPoint(x: rect.midX + r * cos(a), y: rect.midY + r * sin(a))
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        p.closeSubpath()
        return p
    }
}

/// The hexagon is the **space**, the stack is its **content** — as on the
/// table, where round tiles lie in a hex space without filling it. Seen
/// from the side a round tile is a flat rectangle.
///
/// Built from the floor of the cell upwards: three tile heights, as high as
/// a stack may grow, and above them room for the animal cube. It **rests
/// on** the topmost tile instead of covering it, which is why the tiles are
/// flat and it is cubic.
struct CellView: View {
    var stack: [Stone] = []
    var cube = false
    var marker: String? = nil
    /// Does this cell earn points right now? A full tint means yes, a pale
    /// one means landscape without points — a mountain with no mountain
    /// neighbour, a lone field, a branch beside the longest river.
    var scores = false

    private static let rows = 3
    private static let cubeFactor: CGFloat = 1.3

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let gap: CGFloat = 2

            let usable = height * 0.82
            let thickness = (usable - gap * CGFloat(Self.rows - 1) - gap)
                / (CGFloat(Self.rows) + Self.cubeFactor)
            let cubeSide = thickness * Self.cubeFactor
            let baseline = height - height * 0.09

            ZStack {
                // The tint shows the derived landscape, the tiles show the
                // stones. A bare brown or red stone forms no landscape and
                // stays neutral.
                Hexagon().fill(Color(.tertiarySystemFill))
                if let landscape = stack.landscape {
                    Hexagon().fill(landscape.tint.opacity(scores ? 0.45 : 0.15))
                }
                Hexagon().stroke(Color(.separator), lineWidth: 1)

                ForEach(Array(stack.enumerated()), id: \.offset) { fromBottom, stone in
                    RoundedRectangle(cornerRadius: thickness * 0.4)
                        .fill(stone.color)
                        // Follows the appearance: black would be invisible on
                        // a dark ground, leaving two stones of the same colour
                        // indistinguishable when stacked.
                        .overlay(RoundedRectangle(cornerRadius: thickness * 0.4)
                            .strokeBorder(.primary.opacity(0.25), lineWidth: 0.8))
                        .frame(width: width * 0.48, height: thickness)
                        .position(x: width / 2,
                                  y: baseline - CGFloat(fromBottom) * (thickness + gap) - thickness / 2)
                }

                if cube {
                    // The real animal cubes are translucent orange.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.95, green: 0.55, blue: 0.10).opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(.white.opacity(0.9), lineWidth: 1.2))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .frame(width: cubeSide, height: cubeSide)
                        .position(x: width / 2,
                                  y: baseline - CGFloat(stack.count) * (thickness + gap) - cubeSide / 2)
                }

                if let marker {
                    Hexagon().stroke(Color.accentColor, lineWidth: 3)
                    Text(marker)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .position(x: width / 2, y: height * 0.16)
                }
            }
        }
    }
}

/// A player board as a hex grid. Columns from left to right, even columns
/// half a cell lower — the geometry from `regeln-basisspiel.md`.
struct BoardView: View {
    struct Cell {
        var stack: [Stone] = []
        var cube = false
        var marker: String? = nil
    }

    let side: BoardSide
    /// Spaces per column: side A is 5-4-5-4-5, side B is 4-3-4-3-4-3-4.
    let columns: [Int]
    /// Cells under their name `<column><row>`.
    var cells: [Int: Cell] = [:]

    private var maxRows: Int { columns.max() ?? 0 }

    private var scoring: Set<Int> {
        BoardScoring(side: side, columns: columns,
                     stacks: cells.compactMapValues { $0.stack.isEmpty ? nil : $0.stack })
            .scoringCells()
    }

    var body: some View {
        GeometryReader { geo in
            // width = R·(1.5·columns + 0.5), height = √3·R·maxRows
            let rByWidth = geo.size.width / (1.5 * CGFloat(columns.count) + 0.5)
            let rByHeight = geo.size.height / (sqrt(3) * CGFloat(maxRows))
            let r = min(rByWidth, rByHeight)
            let cellHeight = sqrt(3) * r
            let scoring = scoring

            ZStack(alignment: .topLeading) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, count in
                    let column = index + 1
                    ForEach(1...count, id: \.self) { row in
                        let name = column * 10 + row
                        let offset: CGFloat = column % 2 == 0 ? cellHeight / 2 : 0
                        CellView(stack: cells[name]?.stack ?? [],
                                 cube: cells[name]?.cube ?? false,
                                 marker: cells[name]?.marker,
                                 scores: scoring.contains(name))
                            .frame(width: 2 * r, height: cellHeight)
                            .offset(x: 1.5 * r * CGFloat(index),
                                    y: cellHeight * CGFloat(row - 1) + offset)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio((1.5 * CGFloat(columns.count) + 0.5) / (sqrt(3) * CGFloat(maxRows)),
                     contentMode: .fit)
    }
}

extension BoardView {
    static let sideA = [5, 4, 5, 4, 5]
    static let sideB = [4, 3, 4, 3, 4, 3, 4]

    /// Side A: every cell state once, and every scoring condition once met
    /// and once missed.
    static var sampleCellsA: [Int: Cell] {
        [
            // River down column one, with a branch at 23 that does not count
            11: Cell(stack: [.water]),
            12: Cell(stack: [.water], cube: true),
            13: Cell(stack: [.water]),
            14: Cell(stack: [.water]),
            15: Cell(stack: [.water]),
            23: Cell(stack: [.water]),

            // A mountain of height three with no mountain neighbour: worth
            // seven points and scoring zero
            21: Cell(stack: [.stone, .stone, .stone]),
            22: Cell(stack: [.leaves]),                        // tree, height 1
            24: Cell(stack: [.wood, .leaves]),                 // tree, height 2

            // two adjacent mountains — both score
            31: Cell(stack: [.stone]),
            32: Cell(stack: [.stone, .stone]),

            33: Cell(stack: [.stone, .brick]),                 // building on stone
            34: Cell(stack: [.field]),                         // lone field, scores 0
            35: Cell(stack: [.brick, .brick]),                 // building at the rim, too few colours

            41: Cell(stack: [.wood]),                          // bare wood
            42: Cell(stack: [.wood, .brick]),                  // building on wood
            43: Cell(stack: [.wood, .wood, .leaves], cube: true),  // tree, height 3

            51: Cell(stack: [.field]),
            52: Cell(stack: [.field]),                         // field group of two — scores
            53: Cell(stack: [.water]),                         // short river, not the longest
            54: Cell(stack: [.brick]),                         // bare brick
            55: Cell(stack: [.stone]),                         // mountain without neighbour
        ]
    }

    /// Side B: column four is all water and splits the board into two
    /// islands, so those three cells count. The water at 21 separates
    /// nothing.
    static var sampleCellsB: [Int: Cell] {
        [
            11: Cell(stack: [.leaves]),
            12: Cell(stack: [.wood, .leaves]),
            21: Cell(stack: [.water]),
            31: Cell(stack: [.stone]),
            32: Cell(stack: [.stone, .stone]),
            41: Cell(stack: [.water]),
            42: Cell(stack: [.water]),
            43: Cell(stack: [.water]),
            51: Cell(stack: [.field]),
            52: Cell(stack: [.field]),
            61: Cell(stack: [.stone]),
            62: Cell(stack: [.wood, .brick]),
            63: Cell(stack: [.leaves]),
            71: Cell(stack: [.wood, .brick]),
        ]
    }
}

#Preview {
    VStack(spacing: 24) {
        BoardView(side: .a, columns: BoardView.sideA, cells: BoardView.sampleCellsA)
        BoardView(side: .b, columns: BoardView.sideB, cells: BoardView.sampleCellsB)
    }
    .padding()
}
