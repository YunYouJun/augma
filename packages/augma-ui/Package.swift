// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AugmaUI",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "AugmaUI", targets: ["AugmaUI"]),
  ],
  targets: [
    .target(name: "AugmaUI"),
    .testTarget(name: "AugmaUITests", dependencies: ["AugmaUI"]),
  ]
)
