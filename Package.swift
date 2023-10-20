// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TaoBaoSpider",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "TaoBaoSpider", targets: ["TaoBaoSpider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Zean-Technology-Co-Ltd/NNToast.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/Moya/Moya.git", .upToNextMajor(from: "15.0.0"))
    ],
    targets: [
        .target(
            name: "TaoBaoSpider",
            dependencies: [
              "Moya",
              "NNToast",
              .product(name: "HUD", package: "NNToast")
            ]),
        .testTarget(
            name: "TaoBaoSpiderTests",
            dependencies: ["TaoBaoSpider"]),
    ]
)

