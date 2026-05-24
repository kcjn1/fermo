// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Fermo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "FermoCore", targets: ["FermoCore"]),
        .library(name: "FermoSystem", targets: ["FermoSystem"]),
        .executable(name: "FermoApp", targets: ["FermoApp"]),
        .executable(name: "FermoHelper", targets: ["FermoHelper"])
    ],
    targets: [
        .target(name: "FermoCore"),
        .target(
            name: "FermoSystem",
            dependencies: ["FermoCore"]
        ),
        .executableTarget(
            name: "FermoApp",
            dependencies: ["FermoCore", "FermoSystem"]
        ),
        .executableTarget(
            name: "FermoHelper",
            dependencies: ["FermoCore", "FermoSystem"]
        ),
        .testTarget(
            name: "FermoCoreTests",
            dependencies: ["FermoCore"]
        ),
        .testTarget(
            name: "FermoSystemTests",
            dependencies: ["FermoSystem"]
        )
    ]
)
