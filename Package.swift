// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AstroBoyero",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AstroBoyero", targets: ["AstroBoyero"])],
    targets: [
        .target(name: "AstroCore"),
        .executableTarget(name: "AstroBoyero", dependencies: ["AstroCore"]),
        .executableTarget(name: "AstroCoreChecks", dependencies: ["AstroCore"], path: "Tests/AstroCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
