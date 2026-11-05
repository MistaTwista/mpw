// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MPWCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MPWCore", targets: ["MPWCore"]),
    ],
    targets: [
        .target(
            name: "CScrypt",
            cSettings: [.unsafeFlags(["-O2"])]
        ),
        .target(name: "MPWCore", dependencies: ["CScrypt"]),
        .testTarget(name: "MPWCoreTests", dependencies: ["MPWCore", "CScrypt"]),
    ]
)
