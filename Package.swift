// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pokemon-battle",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "pokemon-battle",
            targets: ["pokemon-battle"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "pokemon-battle",
            dependencies: [],
            path: "Sources/pokemon-battle",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
