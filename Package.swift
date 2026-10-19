// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KelawdiSquad",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "KelawdiSquad", path: "Sources/KelawdiSquad")]
)
