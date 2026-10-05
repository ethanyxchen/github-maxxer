// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Hammertime",
  platforms: [.macOS(.v26)],
  products: [
    .executable(name: "Hammertime", targets: ["GitHubMaxxer"])
  ],
  targets: [
    .target(name: "GitHubMaxxerCore"),
    .executableTarget(
      name: "GitHubMaxxer", dependencies: ["GitHubMaxxerCore"], resources: [.process("Resources")]),
    .testTarget(name: "GitHubMaxxerTests", dependencies: ["GitHubMaxxerCore", "GitHubMaxxer"]),
  ]
)
