// swift-tools-version: 6.0
// MacMusic Transfer Utility (Documentation/SPECIFICATION.md §15): the
// engine as a library, its tests, and (Stage 1) a developer's tool that
// builds an image, and the SwiftUI app (tools/build-app.sh wraps it).
import PackageDescription

let package = Package(
    name: "MacMusicTransfer",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "MacMusicTransferKit", targets: ["MacMusicTransferKit"]),
        .executable(name: "mtu-build", targets: ["mtu-build"]),
        .executable(name: "MacMusicTransfer", targets: ["MacMusicTransfer"]),
    ],
    targets: [
        .target(name: "MacMusicTransferKit"),
        .executableTarget(name: "mtu-build", dependencies: ["MacMusicTransferKit"]),
        // The SwiftUI app (Stage 3): the window, and nothing the engine needs.
        .executableTarget(name: "MacMusicTransfer", dependencies: ["MacMusicTransferKit"]),
        .testTarget(name: "MacMusicTransferKitTests", dependencies: ["MacMusicTransferKit"]),
    ]
)
