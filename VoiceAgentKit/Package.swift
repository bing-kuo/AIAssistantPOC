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
        .library(name: "VoiceIntelligence", targets: ["VoiceIntelligence"]),
        .library(name: "STTCore", targets: ["STTCore"]),
        .library(name: "LLMCore", targets: ["LLMCore"]),
        .library(name: "TTSCore", targets: ["TTSCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/microsoft/onnxruntime-swift-package-manager",
            from: "1.24.0"
        ),
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
        .target(
            name: "VoiceIntelligence",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager"),
            ],
            resources: [
                .copy("Resources/silero_vad.onnx"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "VoiceIntelligenceTests",
            dependencies: ["VoiceIntelligence", "VoiceCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "STTCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "STTCoreTests",
            dependencies: ["STTCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "LLMCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "LLMCoreTests",
            dependencies: ["LLMCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "TTSCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "TTSCoreTests",
            dependencies: ["TTSCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
