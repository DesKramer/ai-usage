// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "UsageBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "UsageBar", targets: ["UsageBar"]),
    ],
    targets: [
        .executableTarget(
            name: "UsageBar",
            path: "Sources/UsageBar",
            linkerSettings: [
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
            ]),
        .testTarget(
            name: "UsageBarTests",
            dependencies: ["UsageBar"],
            path: "Tests/UsageBarTests"),
    ])
