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
        .library(name: "VoiceAgentDomain", targets: ["VoiceAgentDomain"]),
        .library(name: "AVAudioCapture", targets: ["AVAudioCapture"]),
        .library(name: "VoiceActivityDetection", targets: ["VoiceActivityDetection"]),
        .library(name: "SileroVAD", targets: ["SileroVAD"]),
        .library(name: "WhisperSTT", targets: ["WhisperSTT"]),
        .library(name: "ProxyLLM", targets: ["ProxyLLM"]),
        .library(name: "AppleTTS", targets: ["AppleTTS"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/microsoft/onnxruntime-swift-package-manager",
            from: "1.24.0"
        ),
    ],
    targets: [
        .target(
            name: "VoiceAgentDomain",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "VoiceAgentDomainTests",
            dependencies: ["VoiceAgentDomain"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "AVAudioCapture",
            dependencies: ["VoiceAgentDomain"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "AVAudioCaptureTests",
            dependencies: ["AVAudioCapture"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "VoiceActivityDetection",
            dependencies: ["VoiceAgentDomain"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "VoiceActivityDetectionTests",
            dependencies: ["VoiceActivityDetection", "SileroVAD", "AVAudioCapture"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "SileroVAD",
            dependencies: [
                "VoiceAgentDomain",
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
            name: "SileroVADTests",
            dependencies: ["SileroVAD"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "WhisperSTT",
            dependencies: ["VoiceAgentDomain"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "WhisperSTTTests",
            dependencies: ["WhisperSTT"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "ProxyLLM",
            dependencies: ["VoiceAgentDomain"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ProxyLLMTests",
            dependencies: ["ProxyLLM"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "AppleTTS",
            dependencies: ["VoiceAgentDomain"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "AppleTTSTests",
            dependencies: ["AppleTTS"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
