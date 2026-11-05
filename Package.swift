// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SK0124",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SK0124",
            path: "Sources/SK0124"
        )
    ]
)
