// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AITerminalCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v17)
    ],
    products: [
        .library(name: "AITerminalCore", targets: ["AITerminalCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.12.1")
    ],
    targets: [
        .target(
            name: "AITerminalCore",
            dependencies: [
                .product(name: "Citadel", package: "Citadel")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
