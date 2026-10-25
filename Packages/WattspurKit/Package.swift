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
        .executable(name: "anonymize-fit", targets: ["anonymize-fit"]),
    ],
    targets: [
        .target(name: "WattspurKit"),
        // Developer tool that makes the sample ride (V-05): swift run anonymize-fit --help
        .executableTarget(name: "anonymize-fit", dependencies: ["WattspurKit"]),
        .testTarget(
            name: "WattspurKitTests",
            dependencies: ["WattspurKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
