// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterWindows",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // OS-independent logic lives here so it can be unit-tested.
        .target(name: "BetterWindowsCore"),
        .executableTarget(
            name: "BetterWindows",
            dependencies: ["BetterWindowsCore"]
        ),
        .testTarget(
            name: "BetterWindowsCoreTests",
            dependencies: ["BetterWindowsCore"]
        ),
    ]
)
