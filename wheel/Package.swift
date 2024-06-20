// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "wheel",
  platforms: [
    .iOS(.v16),
    .macOS(.v11)
  ],
  products: [
    .library(
      name: "wheel",
      targets: ["wheel"]),
  ],
  targets: [
    .target(
      name: "wheel"),
    .testTarget(
      name: "wheelTests",
      dependencies: ["wheel"]),
  ]
)
