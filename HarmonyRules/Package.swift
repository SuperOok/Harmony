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
    products: [.library(name: "HarmonyRules", targets: ["HarmonyRules"])],
    targets: [
        // The card data travels with the rules, not with the app: the
        // storey-one tests must reach it without building a host bundle.
        .target(name: "HarmonyRules", resources: [.process("Resources")]),
        .testTarget(name: "HarmonyRulesTests", dependencies: ["HarmonyRules"]),
        // Counts the move space. Not a test — it answers "how big is this",
        // not "is this right", and `docs/04-architektur.md` asks for the
        // number rather than for a bound.
        .executableTarget(name: "HarmonyMeasure", dependencies: ["HarmonyRules"]),
    ]
)
