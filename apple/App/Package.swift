// swift-tools-version:6.0
// 仅用于在无 Xcode 环境下对 App 源码做 macOS 编译校验。
// 实际打包请用 AITerminal.xcodeproj（xcodegen generate 生成）。
import PackageDescription

let package = Package(
    name: "AppCheck",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AppCheck", targets: ["AppCheck"]),
        .executable(name: "Shots", targets: ["Shots"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.13.0"),
        .package(path: "../AITerminalCore")
    ],
    targets: [
        .target(
            name: "AppCheck",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "AITerminalCore", package: "AITerminalCore")
            ],
            path: "Sources",
            exclude: ["AITerminalApp.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "Shots",
            dependencies: ["AppCheck"],
            path: "ShotsMain",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
