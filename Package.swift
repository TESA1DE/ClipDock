// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ClipDock", platforms: [.macOS(.v14)],
    products: [.executable(name: "ClipDock", targets: ["ClipDock"])],
    targets: [
        .target(name: "ClipDockCore", path: "ClipDock/Models"),
        .executableTarget(name: "ClipDock", dependencies: ["ClipDockCore"], path: "ClipDock",
                          exclude: ["Models", "Resources"]),
        .testTarget(name: "ClipDockIntegrationTests", dependencies: ["ClipDock", "ClipDockCore"], path: "Tests/ClipDockIntegrationTests"),
        .testTarget(name: "ClipDockCoreTests", dependencies: ["ClipDockCore"], path: "Tests/ClipDockCoreTests")
    ]
)
