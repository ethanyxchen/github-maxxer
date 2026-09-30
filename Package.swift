// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "GitHubMaxxer",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "GitHubMaxxer", targets: ["GitHubMaxxer"])
  ],
  targets: [
    .target(name: "GitHubMaxxerCore"),
    .executableTarget(name: "GitHubMaxxer", dependencies: ["GitHubMaxxerCore"]),
    .testTarget(name: "GitHubMaxxerTests", dependencies: ["GitHubMaxxerCore", "GitHubMaxxer"]),
  ]
)
