// swift-tools-version: 6.1
import Foundation
import PackageDescription

let package = Package(
    name: "Flow",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "FlowHotkey",
            path: "Sources/FlowHotkey"
        ),
        .target(
            name: "FlowAudio",
            path: "Sources/FlowAudio"
        ),
        .target(
            name: "FlowUI",
            path: "Sources/FlowUI"
        ),
        // headers + prebuilt lib from Tools/build-whisper.sh, whisper.cpp has no Package.swift
        .target(
            name: "CWhisper",
            path: "Sources/CWhisper",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags(["-L", "vendor/whisper-libs"]),
                .linkedLibrary("whisper-combined"),
                .linkedLibrary("c++"),
                .linkedFramework("Foundation"),
                .linkedFramework("Metal"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreML")
            ]
        ),
        .target(
            name: "FlowTranscribe",
            dependencies: ["CWhisper"],
            path: "Sources/FlowTranscribe"
        ),
        .target(
            name: "FlowInsert",
            path: "Sources/FlowInsert",
            linkerSettings: [.linkedFramework("Carbon")]
        ),
        .target(
            name: "FlowProfiles",
            path: "Sources/FlowProfiles"
        ),
        .target(
            name: "FlowPostProcess",
            dependencies: ["FlowProfiles"],
            path: "Sources/FlowPostProcess"
        ),
        .target(
            name: "FlowClaude",
            dependencies: ["FlowPostProcess", "FlowProfiles"],
            path: "Sources/FlowClaude"
        ),
        .target(
            name: "FlowContext",
            path: "Sources/FlowContext"
        ),
        .target(
            name: "FlowHistory",
            path: "Sources/FlowHistory"
        ),
        .target(
            name: "FlowVocabulary",
            path: "Sources/FlowVocabulary"
        ),
        .executableTarget(
            name: "FlowApp",
            dependencies: [
                "FlowHotkey", "FlowAudio", "FlowUI", "FlowTranscribe", "FlowInsert",
                "FlowProfiles", "FlowPostProcess", "FlowHistory", "FlowVocabulary", "FlowClaude", "FlowContext"
            ],
            path: "Sources/FlowApp",
            swiftSettings: [
                // swiftui macro plugin lives in xcode, see Tools/env.sh
                .unsafeFlags([
                    "-external-plugin-path",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform"
                        + "/Developer/usr/lib/swift/host/plugins#"
                        + "\(NSHomeDirectory())/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain"
                        + "/usr/bin/swift-plugin-server"
                ])
            ]
        ),
        .testTarget(
            name: "FlowHotkeyTests",
            dependencies: ["FlowHotkey"],
            path: "Tests/FlowHotkeyTests"
        )
    ]
)
