// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RimiFirebaseServices",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RimiFirebaseServices",
            targets: ["RimiFirebaseServices"]),
    ],
    dependencies: [
            // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.14.0"),
        .package(url: "https://github.com/rmiron/RimiDefinitions.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RimiFirebaseServices",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "RimiDefinitions", package: "RimiDefinitions"),
            ]
        ),
        .testTarget(
            name: "RimiFirebaseRTDBServiceTests",
            dependencies: ["RimiFirebaseServices"]
        ),
    ]
)
