// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AugmaDesktopDemo",
  platforms: [.macOS(.v26)],
  products: [
    .executable(name: "AugmaDesktopDemo", targets: ["AugmaDesktopDemo"]),
  ],
  dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
  ],
  targets: [
    .executableTarget(name: "AugmaDesktopDemo", dependencies: [.product(name: "MCP", package: "swift-sdk")]),
    .testTarget(name: "AugmaDesktopDemoTests", dependencies: ["AugmaDesktopDemo"]),
  ]
)
