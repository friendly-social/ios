// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Features",
  defaultLocalization: "en",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "AddFriendService", targets: ["AddFriendService"]),
    .library(name: "AuthApi", targets: ["AuthApi"]),
    .library(name: "AuthApiLive", targets: ["AuthApiLive"]),
    .library(name: "AccountSessionService", targets: ["AccountSessionService"]),
    .library(name: "AuthFeature", targets: ["AuthFeature"]),
    .library(name: "CommunityMarkdownFeature", targets: ["CommunityMarkdownFeature"]),
    .library(name: "CommunityMarkdownService", targets: ["CommunityMarkdownService"]),
    .library(name: "CommunityEditorFeature", targets: ["CommunityEditorFeature"]),
    .library(name: "CommunityService", targets: ["CommunityService"]),
    .library(name: "CommunityApi", targets: ["CommunityApi"]),
    .library(name: "CommunityApiLive", targets: ["CommunityApiLive"]),
    .library(name: "CommunityServiceLive", targets: ["CommunityServiceLive"]),
    .library(name: "CommunityDraftService", targets: ["CommunityDraftService"]),
    .library(name: "CommunityDraftServiceLive", targets: ["CommunityDraftServiceLive"]),
    .library(name: "CommunityDraftStorageService", targets: ["CommunityDraftStorageService"]),
    .library(name: "CommunityDraftStorageServiceLive", targets: ["CommunityDraftStorageServiceLive"]),
    .library(name: "CommunityProfileService", targets: ["CommunityProfileService"]),
    .library(name: "CommunityFeature", targets: ["CommunityFeature"]),
    .library(name: "CommunityRootFeature", targets: ["CommunityRootFeature"]),
    .library(name: "DiscoveryFeedService", targets: ["DiscoveryFeedService"]),
    .library(name: "EmailAuthService", targets: ["EmailAuthService"]),
    .library(name: "FriendAccessService", targets: ["FriendAccessService"]),
    .library(name: "FeedFeature", targets: ["FeedFeature"]),
    .library(name: "FeedApi", targets: ["FeedApi"]),
    .library(name: "FeedApiLive", targets: ["FeedApiLive"]),
    .library(name: "FilesApi", targets: ["FilesApi"]),
    .library(name: "FilesApiLive", targets: ["FilesApiLive"]),
    .library(name: "FriendsApi", targets: ["FriendsApi"]),
    .library(name: "FriendsApiLive", targets: ["FriendsApiLive"]),
    .library(name: "FriendlyUIKit", targets: ["FriendlyUIKit"]),
    .library(name: "LiveDependencies", targets: ["LiveDependencies"]),
    .library(name: "NetworkFeature", targets: ["NetworkFeature"]),
    .library(name: "NetworkService", targets: ["NetworkService"]),
    .library(name: "ProfileFormService", targets: ["ProfileFormService"]),
    .library(name: "ProfileApi", targets: ["ProfileApi"]),
    .library(name: "ProfileApiLive", targets: ["ProfileApiLive"]),
    .library(name: "ProfileFeature", targets: ["ProfileFeature"]),
    .library(name: "ProfileService", targets: ["ProfileService"]),
    .library(name: "ScannerFeature", targets: ["ScannerFeature"]),
    .library(name: "CameraPermissionService", targets: ["CameraPermissionService"]),
    .library(name: "QRPhotoImportService", targets: ["QRPhotoImportService"]),
    .library(name: "QRSessionService", targets: ["QRSessionService"]),
    .library(name: "SignUpFeature", targets: ["SignUpFeature"]),
  ],
  dependencies: [
    .package(path: "../Domain"),
    .package(path: "../Infrastructure"),
    .package(url: "https://github.com/dagronf/QRCode", exact: "27.12.0"),
    .package(url: "https://github.com/lorenzofiamingo/swiftui-cached-async-image", exact: "2.1.1"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.12.0"),
    .package(url: "https://github.com/alex-npmn/URLMacro.git", from: "1.0.2"),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.9.0"),
    .package(url: "https://github.com/tevelee/SwiftUI-Flow", exact: "3.1.0"),
  ],
  targets: [
    .target(
      name: "AddFriendService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "AddFriendServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "AddFriendService",
        "FriendsApi",
      ]
    ),
    .target(
      name: "AuthApi",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "AuthApiLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        .product(name: "Networking", package: "Infrastructure"),
        "AuthApi",
      ]
    ),
    .target(
      name: "ProfileApi",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "ProfileApiLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        .product(name: "Networking", package: "Infrastructure"),
        "ProfileApi",
      ]
    ),
    .target(
      name: "FriendsApi",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "FriendsApiLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        .product(name: "Networking", package: "Infrastructure"),
        "FriendsApi",
      ]
    ),
    .target(
      name: "FeedApi",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "FeedApiLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        .product(name: "Networking", package: "Infrastructure"),
        "FeedApi",
      ]
    ),
    .target(
      name: "FilesApi",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "FilesApiLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        .product(name: "Networking", package: "Infrastructure"),
        "FilesApi",
      ]
    ),
    .target(
      name: "AccountSessionService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "FriendlyUIKit",
      dependencies: [
        .product(name: "CachedAsyncImage", package: "swiftui-cached-async-image"),
      ]
    ),
    .target(
      name: "AuthFeature",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "EmailAuthService",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "NetworkQRCodeFeature",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "NetworkService",
      ],
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "CommunityMarkdownService",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown"),
      ]
    ),
    .target(
      name: "ProfileFeature",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Flow", package: "SwiftUI-Flow"),
        .product(name: "Models", package: "Domain"),
        "AuthFeature",
        "ProfileFormService",
        "ProfileService",
        "FriendlyUIKit",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "FeedFeature",
      dependencies: [
        .product(name: "CachedAsyncImage", package: "swiftui-cached-async-image"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Flow", package: "SwiftUI-Flow"),
        .product(name: "Models", package: "Domain"),
        "DiscoveryFeedService",
        "FriendlyUIKit",
        "ProfileFeature",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "SignUpFeature",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Flow", package: "SwiftUI-Flow"),
        .product(name: "Models", package: "Domain"),
        "AuthFeature",
        "ProfileFormService",
        "FriendlyUIKit",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "ScannerFeature",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "AuthFeature",
        "CameraPermissionService",
        "FriendAccessService",
        "QRPhotoImportService",
        "QRSessionService",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "CameraPermissionService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "CameraPermissionServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "CameraPermissionService",
      ]
    ),
    .target(
      name: "QRPhotoImportService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "QRPhotoImportServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "QRCode", package: "QRCode"),
        "QRPhotoImportService",
      ]
    ),
    .target(
      name: "QRSessionService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "QRSessionServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "CameraPermissionService",
        "QRSessionService",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "NetworkFeature",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "NetworkService",
        "FriendlyUIKit",
        "NetworkQRCodeFeature",
        "ProfileFeature",
        "ScannerFeature",
      ],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "CommunityMarkdownFeature",
      dependencies: [
        .product(name: "CachedAsyncImage", package: "swiftui-cached-async-image"),
        "CommunityMarkdownService",
      ],
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "CommunityEditorFeature",
      dependencies: [
        "CommunityMarkdownFeature",
        "CommunityMarkdownService",
      ],
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "CommunityService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "CommunityApi",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        "CommunityService",
      ]
    ),
    .target(
      name: "CommunityApiLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Networking", package: "Infrastructure"),
        "CommunityApi",
        "CommunityService",
      ]
    ),
    .target(
      name: "CommunityServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "AccountStorageService", package: "Infrastructure"),
        "CommunityApi",
        "CommunityService",
      ]
    ),
    .target(
      name: "CommunityDraftService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        "CommunityService",
      ]
    ),
    .target(
      name: "CommunityDraftServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "CommunityDraftService",
        "CommunityDraftStorageService",
        "CommunityMarkdownService",
        "CommunityService",
      ]
    ),
    .target(
      name: "CommunityDraftStorageService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        "CommunityDraftService",
      ]
    ),
    .target(
      name: "CommunityDraftStorageServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "CommunityDraftService",
        "CommunityDraftStorageService",
      ]
    ),
    .target(
      name: "CommunityProfileService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        "CommunityService",
      ]
    ),
    .target(
      name: "CommunityProfileServiceLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        .product(name: "AccountStorageService", package: "Infrastructure"),
        "AccountSessionService",
        "CommunityProfileService",
        "CommunityService",
        "FilesApi",
        "ProfileApi",
      ]
    ),
    .target(
      name: "CommunityFeature",
      dependencies: [
        .product(name: "CachedAsyncImage", package: "swiftui-cached-async-image"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        "CommunityDraftService",
        "CommunityEditorFeature",
        "CommunityMarkdownFeature",
        "CommunityMarkdownService",
        "CommunityProfileService",
        "CommunityService",
        "FriendlyUIKit",
      ],
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "CommunityFeatureLive",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        "CommunityFeature",
        "CommunityMarkdownService",
      ]
    ),
    .target(
      name: "CommunityRootFeature",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "CommunityFeature",
        "CommunityService",
        "FriendlyUIKit",
        "ProfileFeature",
      ],
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "DiscoveryFeedService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "EmailAuthService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "FriendAccessService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "NetworkService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "ProfileFormService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "ProfileService",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
      ]
    ),
    .target(
      name: "AccountSessionServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "AccountSessionService",
        "CommunityDraftService",
      ]
    ),
    .target(
      name: "DiscoveryFeedServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "DiscoveryFeedService",
        "FeedApi",
        "FilesApi",
        "FriendsApi",
      ]
    ),
    .target(
      name: "EmailAuthServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        "AccountSessionService",
        .product(name: "Dependencies", package: "swift-dependencies"),
        "AuthApi",
        "EmailAuthService",
      ]
    ),
    .target(
      name: "FriendAccessServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        "AccountSessionService",
        "AddFriendService",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "FriendAccessService",
      ]
    ),
    .target(
      name: "NetworkServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "QRCode", package: "QRCode"),
        .product(name: "URLMacro", package: "URLMacro"),
        "NetworkService",
        "FilesApi",
        "FriendsApi",
      ]
    ),
    .target(
      name: "ProfileFormServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "AuthApi",
        "FilesApi",
        "ProfileApi",
        "ProfileFormService",
      ]
    ),
    .target(
      name: "ProfileServiceLive",
      dependencies: [
        .product(name: "AccountStorageService", package: "Infrastructure"),
        "AccountSessionService",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Models", package: "Domain"),
        "FilesApi",
        "FriendsApi",
        "ProfileApi",
        "ProfileService",
      ]
    ),
    .target(
      name: "LiveDependencies",
      dependencies: [
        .product(name: "NetworkingLive", package: "Infrastructure"),
        .product(name: "StorageServiceLive", package: "Infrastructure"),
        .product(name: "AccountStorageServiceLive", package: "Infrastructure"),
        "AccountSessionServiceLive",
        "AddFriendServiceLive",
        "AuthApiLive",
        "CommunityApiLive",
        "CommunityDraftServiceLive",
        "CommunityDraftStorageServiceLive",
        "CommunityFeatureLive",
        "CommunityProfileServiceLive",
        "CommunityServiceLive",
        "DiscoveryFeedServiceLive",
        "EmailAuthServiceLive",
        "FeedApiLive",
        "FilesApiLive",
        "FriendAccessServiceLive",
        "FriendsApiLive",
        "NetworkServiceLive",
        "ProfileApiLive",
        "ProfileFormServiceLive",
        "ProfileServiceLive",
        "CameraPermissionServiceLive",
        "QRPhotoImportServiceLive",
        "QRSessionServiceLive",
      ]
    ),
    .testTarget(
      name: "CommunityFeatureTests",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Networking", package: "Infrastructure"),
        "CommunityApi",
        "CommunityApiLive",
        "CommunityDraftService",
        "CommunityDraftServiceLive",
        "CommunityFeature",
        "CommunityMarkdownService",
        "CommunityProfileService",
        "CommunityService",
        "CommunityServiceLive",
      ]
    ),
    .testTarget(
      name: "CommunityMarkdownServiceTests",
      dependencies: [
        "CommunityMarkdownService",
      ]
    ),
    .testTarget(
      name: "CommunityEditorFeatureTests",
      dependencies: [
        "CommunityEditorFeature",
      ]
    ),
    .testTarget(
      name: "CommunityMarkdownFeatureTests",
      dependencies: [
        "CommunityMarkdownFeature",
      ]
    ),
  ]
)
