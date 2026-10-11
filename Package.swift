// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-qr-kit",
    platforms: [
        .macOS(.v13), .iOS(.v16), .tvOS(.v16), .visionOS(.v1)
    ],
    products: [
        .library(name: "QRKit", targets: ["QRKit"]),
    ],
    targets: [
        .target(name: "QRKit"),
        .testTarget(name: "QRKitTests", dependencies: ["QRKit"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
