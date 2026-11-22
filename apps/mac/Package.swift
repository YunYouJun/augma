// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AugmaDesktopDemo",
  platforms: [.macOS(.v26)],
  products: [
    .executable(name: "AugmaDesktopDemo", targets: ["AugmaDesktopDemo"]),
  ],
  dependencies: [
    .package(path: "../../packages/augma-ui"),
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
  ],
  targets: [
    .executableTarget(
      name: "AugmaDesktopDemo",
      dependencies: [
        .product(name: "AugmaUI", package: "augma-ui"),
        .product(name: "MCP", package: "swift-sdk"),
      ]
    ),
    .testTarget(
      name: "AugmaDesktopDemoTests",
      dependencies: [
        "AugmaDesktopDemo",
        .product(name: "AugmaUI", package: "augma-ui"),
      ]
    ),
  ]
)
