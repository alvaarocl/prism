// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Prism", platforms: [.macOS(.v14)], products: [
    .executable(name: "Prism", targets: ["Prism"])
], targets: [
    .target(name: "PrismCore"),
    .executableTarget(name: "Prism", dependencies: ["PrismCore"], resources: [.process("Resources")], linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("AppKit")]),
    .testTarget(name: "PrismCoreTests", dependencies: ["PrismCore"])
])
