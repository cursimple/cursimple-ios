// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CurSimpleCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "CurSimpleCore", targets: ["CurSimpleCore"]),
    ],
    targets: [
        .target(
            name: "CurSimpleCore",
            resources: [.copy("Plugins/Resources/schools.json")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CurSimpleCoreTests",
            dependencies: ["CurSimpleCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
