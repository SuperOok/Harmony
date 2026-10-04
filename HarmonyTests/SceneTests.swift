import Testing
import SwiftUI
@testable import Harmony

/// The squirrel's scene: the display list that `tools/szenen/export.py`
/// writes, and the animation that moves through it.
@Suite("Tierszene")
struct SceneTests {
    private func list() throws -> SceneDisplayList {
        try #require(SceneDisplayList.load(named: "szene-eichhoernchen"), "Die Anzeigeliste fehlt im Bündel.")
    }

    @Test("Die Anzeigeliste lässt sich laden und hat Inhalt")
    func theListLoads() throws {
        let list = try list()
        #expect(list.scene.count > 1000)
        #expect(!list.squirrel.nodes.isEmpty)
        #expect(list.view.width > 0 && list.view.height > 0)
    }

    @Test("Die bewegten Teile des Tiers sind benannt")
    func theMovingPartsAreNamed() throws {
        func ids(_ nodes: [SceneNode]) -> Set<String> {
            nodes.reduce(into: []) { acc, n in
                if let id = n.id { acc.insert(id) }
                acc.formUnion(ids(n.children ?? []))
            }
        }
        #expect(ids(try list().squirrel.nodes) == ["tail", "nut", "eye"])
    }

    @Test("Die Kamera beginnt nah, endet auf dem Lebensraum; das Tier beginnt unsichtbar und endet auf dem Dach")
    func theAnimationRunsFromCloseToHabitat() throws {
        let list = try list()
        let timeline = SquirrelTimeline(anchors: list.anchors)
        let first = timeline.pose(at: 0)
        #expect(first.view == list.anchors.close)
        #expect(first.alpha == 0)

        let last = timeline.pose(at: SquirrelTimeline.length)
        #expect(abs(last.view.width - list.anchors.habitat.width) < 1e-9)
        #expect(last.feet == list.anchors.ridgeMid)
        #expect(last.alpha == 1)
    }

    @Test("Die Kamera zoomt nur heraus, nie wieder herein")
    func theCameraOnlyZoomsOut() throws {
        let timeline = SquirrelTimeline(anchors: try list().anchors)
        var width = 0.0
        for step in 0...Int(SquirrelTimeline.length * 25) {
            let w = timeline.pose(at: Double(step) / 25).view.width
            #expect(w >= width - 1e-9)
            width = w
        }
    }
}
