// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.photos",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.photos",
            targets: [
                "com.awareframework.ios.sensor.photos"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.photos",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/com.awareframework.ios.sensor.photos"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.photosTests",
            dependencies: [
                .target(name: "com.awareframework.ios.sensor.photos")
            ],
            path: "Tests/com.awareframework.ios.sensor.photosTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
