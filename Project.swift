import ProjectDescription

let project = Project(
    name: "Friendly",
    packages: [
        .local(path: "Packages/Domain"),
        .local(path: "Packages/Features"),
        .local(path: "Packages/Infrastructure"),
    ],
    targets: [
        .target(
            name: "Friendly",
            destinations: .iOS,
            product: .app,
            bundleId: "me.y9san9.Friendly",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "ITSAppUsesNonExemptEncryption": false,
                "NSCameraUsageDescription": "Friendly needs access to your camera to scan QR codes and add friends.",
                "NSPhotoLibraryUsageDescription": "Friendly needs access to your photo library to let you pick QR codes from your photos or upload a profile picture.",
                "UILaunchScreen": [
                    "UIColorName": "",
                    "UIImageName": "",
                ],
                "CFBundleURLTypes": [
                    [
                        "CFBundleURLSchemes": ["friendly"],
                        "CFBundleURLName": "me.y9san9.Friendly",
                    ],
                ],
            ]),
            buildableFolders: [
                "App/Sources",
                "App/Resources",
            ],
            dependencies: [
                .package(product: "Dependencies"),
                .package(product: "CommunityRootFeature"),
                .package(product: "FeedFeature"),
                .package(product: "FriendAccessService"),
                .package(product: "ProfileFormService"),
                .package(product: "FriendlyUIKit"),
                .package(product: "LiveDependencies"),
                .package(product: "Models"),
                .package(product: "NetworkFeature"),
                .package(product: "ProfileFeature"),
                .package(product: "ScannerFeature"),
                .package(product: "SignUpFeature"),
            ],
            settings: .settings(
                base: [
                    "OTHER_LDFLAGS": "-ObjC",
                    "MARKETING_VERSION": "1.0",
                    "CURRENT_PROJECT_VERSION": "1",
                    "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
                ],
            )
        ),
        .target(
            name: "CommunityTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "me.y9san9.Friendly.CommunityTests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: ["Packages/Features/Tests/**"],
            dependencies: [
                .package(product: "CommunityApi"),
                .package(product: "CommunityApiLive"),
                .package(product: "CommunityDraftService"),
                .package(product: "CommunityDraftServiceLive"),
                .package(product: "CommunityDraftStorageServiceLive"),
                .package(product: "CommunityEditorFeature"),
                .package(product: "CommunityFeature"),
                .package(product: "CommunityMarkdownFeature"),
                .package(product: "CommunityMarkdownService"),
                .package(product: "CommunityProfileService"),
                .package(product: "CommunityService"),
                .package(product: "CommunityServiceLive"),
                .package(product: "Networking"),
                .package(product: "Dependencies"),
            ]
        ),
    ],
)
