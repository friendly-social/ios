import ProjectDescription

let project = Project(
    name: "Friendly",
    targets: [
        .target(
            name: "Friendly",
            destinations: .iOS,
            product: .app,
            bundleId: "me.y9san9.Friendly",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
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
