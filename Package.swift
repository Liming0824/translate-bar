// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TranslateBar",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "TranslateBar",
            dependencies: ["HotKey"],
            path: "Sources/TranslateBar",
            exclude: ["Resources/Info.plist"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "TranslateBarTests",
            dependencies: [
                "TranslateBar",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/TranslateBarTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
