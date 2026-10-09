// swift-tools-version: 6.0
// MacMusic Transfer Utility (Documentation/SPECIFICATION.md §15): the
// engine as a library, its tests, and (Stage 1) a developer's tool that
// builds an image. The SwiftUI app comes in Stage 3.
import PackageDescription

let package = Package(
    name: "MacMusicTransfer",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "MacMusicTransferKit", targets: ["MacMusicTransferKit"]),
        .executable(name: "mtu-build", targets: ["mtu-build"]),
    ],
    targets: [
        .target(name: "MacMusicTransferKit"),
        .executableTarget(name: "mtu-build", dependencies: ["MacMusicTransferKit"]),
        .testTarget(name: "MacMusicTransferKitTests", dependencies: ["MacMusicTransferKit"]),
    ]
)
