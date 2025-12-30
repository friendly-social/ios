import ProjectDescription

let project = Project(
    name: "Friendly",
    packages: [
        .remote(
            url: "https://github.com/tevelee/SwiftUI-Flow",
            requirement: .exact("3.1.0"),
        ),
    ],
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
                .package(product: "Flow"),
            ]
        ),
    ]
)
