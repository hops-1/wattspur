// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WattspurKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "WattspurKit", targets: ["WattspurKit"]),
        .library(name: "WattspurCore", targets: ["WattspurCore"]),
        .executable(name: "anonymize-fit", targets: ["anonymize-fit"]),
    ],
    targets: [
        // Pure code without SwiftData: the FIT and GPX readers, the values rides are made of, and
        // the analyses on them. It must stay free of SwiftData and SwiftUI (docs/ARCHITECTURE.md).
        .target(name: "WattspurCore"),
        // The store: the SwiftData models, the RideLibrary and the watched-folder import. It keeps
        // the name WattspurKit so the model classes stay in the module they were in.
        .target(name: "WattspurKit", dependencies: ["WattspurCore"]),
        // Developer tool that makes the sample ride (V-05): swift run anonymize-fit --help
        .executableTarget(name: "anonymize-fit", dependencies: ["WattspurCore"]),
        // The FIT and GPX files of the tests, shared by both test targets.
        .target(name: "TestFixtures", path: "Tests/TestFixtures", resources: [.copy("Fixtures")]),
        .testTarget(name: "WattspurCoreTests", dependencies: ["WattspurCore", "TestFixtures"]),
        .testTarget(name: "WattspurKitTests", dependencies: ["WattspurKit", "WattspurCore", "TestFixtures"]),
    ]
)
