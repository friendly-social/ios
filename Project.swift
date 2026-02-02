import ProjectDescription

let project = Project(
    name: "Friendly",
    targets: [
        .target(
            name: "Friendly",
            destinations: .iOS,
            product: .app,
            bundleId: "me.y9san9.Friendly",
            infoPlist: .extendingDefault(with: [
                "ITSAppUsesNonExemptEncryption": false,
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
                "Friendly/Sources",
                "Friendly/Resources",
            ],
            dependencies: [
                .external(name: "Flow"),
                .external(name: "QRCode"),
                .external(name: "CachedAsyncImage"),
            ],
            settings: .settings(
                base: [
                    "OTHER_LDFLAGS": "-ObjC"
                ],
            )
        ),
    ],
)
