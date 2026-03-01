// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TranslateBar",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "TranslateBar",
            dependencies: ["HotKey"],
            path: "Sources/TranslateBar",
            resources: [
                .copy("Resources/Info.plist"),
            ]
        ),
        .testTarget(
            name: "TranslateBarTests",
            dependencies: ["TranslateBar"],
            path: "Tests/TranslateBarTests"
        ),
    ]
)
