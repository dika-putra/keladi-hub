// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeProfiles",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "ClaudeProfiles", path: "Sources/ClaudeProfiles")]
)
