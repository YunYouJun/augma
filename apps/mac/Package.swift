// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AugmaDesktopDemo",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "AugmaDesktopDemo", targets: ["AugmaDesktopDemo"]),
  ],
  targets: [
    .executableTarget(name: "AugmaDesktopDemo"),
    .testTarget(name: "AugmaDesktopDemoTests", dependencies: ["AugmaDesktopDemo"]),
  ]
)
