// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Prism", platforms: [.macOS(.v14)], products: [
    .executable(name: "Prism", targets: ["Prism"]),
    .executable(name: "PrismAgent", targets: ["PrismAgent"])
], targets: [
    .target(name: "PrismCore"),
    .target(name: "PrismHardware", dependencies: ["PrismCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .executableTarget(name: "PrismAgent", dependencies: ["PrismCore", "PrismHardware"], linkerSettings: [.linkedFramework("IOKit")]),
    .executableTarget(name: "Prism", dependencies: ["PrismCore"], resources: [.process("Resources")], linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("AppKit"), .linkedFramework("ServiceManagement")]),
    .testTarget(name: "PrismCoreTests", dependencies: ["PrismCore"])
])
