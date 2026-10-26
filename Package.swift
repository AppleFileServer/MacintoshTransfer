// swift-tools-version: 6.0
// Macintosh Transfer Utility (Documentation/SPECIFICATION.md §15): the
// engine as a library, its tests, and (Stage 1) a developer's tool that
// builds an image, and the SwiftUI app (tools/build-app.sh wraps it).
import PackageDescription

let package = Package(
    name: "MacintoshTransfer",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "MacintoshTransferKit", targets: ["MacintoshTransferKit"]),
        .executable(name: "mtu-build", targets: ["mtu-build"]),
        .executable(name: "MacintoshTransfer", targets: ["MacintoshTransfer"]),
    ],
    targets: [
        .target(name: "MacintoshTransferKit"),
        .executableTarget(name: "mtu-build", dependencies: ["MacintoshTransferKit"]),
        // The SwiftUI app (Stage 3): the window, and nothing the engine needs.
        .executableTarget(name: "MacintoshTransfer", dependencies: ["MacintoshTransferKit"]),
        .testTarget(name: "MacintoshTransferKitTests", dependencies: ["MacintoshTransferKit"]),
    ]
)
