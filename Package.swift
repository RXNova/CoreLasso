// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoreLasso",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LassoCore", targets: ["LassoCore"]),
        .library(name: "LassoData", targets: ["LassoData"]),
        .library(name: "LassoUI", targets: ["LassoUI"]),
    ],
    targets: [
        .target(
            name: "LassoCore",
            path: "Sources/LassoCore"
        ),
        .target(
            name: "LassoData",
            dependencies: ["LassoCore"],
            path: "Sources/LassoData",
            linkerSettings: [.linkedFramework("Virtualization")]
        ),
        .target(
            name: "LassoUI",
            dependencies: ["LassoCore", "LassoData"],
            path: "Sources/LassoUI",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "CoreLassoApp",
            dependencies: ["LassoCore", "LassoData", "LassoUI"],
            path: "Sources/CoreLassoApp"
        ),
        .executableTarget(
            name: "lasso",
            dependencies: ["LassoCore", "LassoData"],
            path: "Sources/LassoCLI"
        ),
        .testTarget(
            name: "LassoCoreTests",
            dependencies: ["LassoCore"]
        ),
        .testTarget(
            name: "LassoDataTests",
            dependencies: ["LassoData", "LassoCore"]
        ),
    ]
)
