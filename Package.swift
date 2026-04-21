// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GeniusMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GeniusMac", targets: ["GeniusMac"])
    ],
    targets: [
        .executableTarget(
            name: "GeniusMac",
            path: "GeniusMac",
            exclude: [
                "Resources",
                "Assets.xcassets",
                ".DS_Store"
            ]
        )
    ]
)
