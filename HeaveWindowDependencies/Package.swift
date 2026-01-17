// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HeaveWindowDependencies",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "HeaveWindowDependencies",
            targets: ["HeaveWindowDependencies"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "HeaveWindowDependencies",
            dependencies: [
                "Sparkle",
                "Yams",
            ]
        ),
    ]
)
