// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeNotifier",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeNotifier",
            path: "Sources/ClaudeNotifier",
            exclude: ["App/Info.plist", "Vendor"]
        )
    ]
)
