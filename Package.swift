// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Portside",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Portside", path: "Sources/Portside")
    ]
)
