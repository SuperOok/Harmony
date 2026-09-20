// swift-tools-version: 6.0
import PackageDescription

/// The rules, separate from the app.
///
/// `04-architektur.md` asks for the engine as its own module, and
/// `pruefverfahren.md` gives the reason: storey one tests run against plain
/// functions over data structures. Without a host app they take seconds
/// instead of minutes, which is what makes it bearable to run them on every
/// change. Nothing in here may import SwiftUI — a colour is presentation,
/// not a rule.
let package = Package(
    name: "HarmonyRules",
    products: [
        .library(name: "HarmonyRules", targets: ["HarmonyRules"]),
        .library(name: "HarmonyEngine", targets: ["HarmonyEngine"]),
    ],
    targets: [
        // The card data travels with the rules, not with the app: the
        // storey-one tests must reach it without building a host bundle.
        .target(name: "HarmonyRules", resources: [.process("Resources")]),
        // The procedure, separate from the rules. The dependency runs one
        // way only and the compiler holds it there: state, move generation,
        // evaluation and search may ask the rules anything, and the rules
        // know nothing of them.
        .target(name: "HarmonyEngine", dependencies: ["HarmonyRules"]),
        .testTarget(name: "HarmonyRulesTests", dependencies: ["HarmonyRules"]),
        .testTarget(name: "HarmonyEngineTests", dependencies: ["HarmonyEngine"]),
        // Counts the move space. Not a test — it answers "how big is this",
        // not "is this right", and `docs/04-architektur.md` asks for the
        // number rather than for a bound.
        .executableTarget(name: "HarmonyMeasure", dependencies: ["HarmonyEngine"]),
    ]
)
