// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AlgoCV",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AlgoCV", targets: ["AlgoCV"]),
    ],
    dependencies: [
        .package(path: "../AlgoCVData"),
        .package(path: "../../impro.swift"),
        .package(url: "https://github.com/yeatse/opencv-spm.git", from: "4.13.0"),
    ],
    targets: [
        .target(
            name: "AlgoCV",
            dependencies: [
                .product(name: "AlgoCVData", package: "AlgoCVData"),
                .product(name: "ImPro", package: "impro.swift"),
                .product(name: "OpenCV", package: "opencv-spm"),
                "AlgoCVMetal",
            ]
        ),
        .target(
            name: "AlgoCVMetal",
            dependencies: [
                .product(name: "AlgoCVData", package: "AlgoCVData"),
            ],
            resources: [.process("Shaders")]
        ),
        .testTarget(
            name: "AlgoCVTests",
            dependencies: ["AlgoCV"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
