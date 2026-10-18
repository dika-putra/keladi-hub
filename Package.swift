// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeladiHub",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "KeladiHub", path: "Sources/KeladiHub")]
)
