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
