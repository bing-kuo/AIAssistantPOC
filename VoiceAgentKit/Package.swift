// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceAgentKit",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .visionOS("26.0"),
    ],
    products: [
        .library(name: "VoiceCore", targets: ["VoiceCore"]),
    ],
    targets: [
        .target(
            name: "VoiceCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "VoiceCoreTests",
            dependencies: ["VoiceCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
