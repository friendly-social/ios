// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Infrastructure",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "AccountStorageService", targets: ["AccountStorageService"]),
    .library(name: "AccountStorageServiceLive", targets: ["AccountStorageServiceLive"]),
    .library(name: "ImageService", targets: ["ImageService"]),
    .library(name: "ImageServiceLive", targets: ["ImageServiceLive"]),
    .library(name: "Networking", targets: ["Networking"]),
    .library(name: "NetworkingLive", targets: ["NetworkingLive"]),
    .library(name: "StorageService", targets: ["StorageService"]),
    .library(name: "StorageServiceLive", targets: ["StorageServiceLive"]),
  ],
  dependencies: [
    .package(path: "../Domain"),
    .package(url: "https://github.com/kean/Nuke", exact: "13.2.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", exact: "1.7.3"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.12.0"),
    .package(url: "https://github.com/alex-npmn/URLMacro.git", from: "1.0.2"),
  ],
  targets: [
    .target(
      name: "AccountStorageService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "AccountStorageServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "AccountStorageService",
        "StorageService",
      ]
    ),
    .target(
      name: "ImageService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "ImageServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Nuke", package: "Nuke"),
        "ImageService",
      ]
    ),
    .target(
      name: "Networking",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "NetworkingLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "URLMacro", package: "URLMacro"),
        "Networking",
      ]
    ),
    .target(
      name: "StorageService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "StorageServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "StorageService",
      ]
    ),
    .testTarget(
      name: "ImageServiceTests",
      dependencies: [
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Nuke", package: "Nuke"),
        .product(name: "NukeUI", package: "Nuke"),
        "ImageService",
        "ImageServiceLive",
      ]
    ),
  ]
)
