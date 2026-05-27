// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RecordReader",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "RecordReaderCore", targets: ["RecordReaderCore"])
    ],
    targets: [
        .target(name: "RecordReaderCore"),
        .testTarget(
            name: "RecordReaderCoreTests",
            dependencies: ["RecordReaderCore"]
        )
    ]
)
