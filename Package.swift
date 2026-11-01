// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScrollCapture",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "ScrollCapture", targets: ["ScrollCapture"])],
    targets: [
        .target(name: "CaptureCore"),
        .executableTarget(name: "ScrollCapture", dependencies: ["CaptureCore"]),
        .testTarget(name: "CaptureCoreTests", dependencies: ["CaptureCore"])
    ]
)
