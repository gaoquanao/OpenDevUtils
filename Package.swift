// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenDevUtils",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OpenDevUtils",
            path: "devUtils"
        ),
        .testTarget(
            name: "OpenDevUtilsTests",
            dependencies: ["OpenDevUtils"],
            path: "Tests"
        )
    ]
)
