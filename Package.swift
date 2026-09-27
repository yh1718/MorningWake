// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MorningWake",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MorningWake", targets: ["MorningWake"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MorningWake",
            dependencies: [],
            path: "Sources/MorningWake",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MorningWakeTests",
            dependencies: ["MorningWake"]
        )
    ]
)
