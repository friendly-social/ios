import ProjectDescription

let project = Project(
  name: "CommunityEditorPrototype",
  packages: [.local(path: "../../Packages/Features")],
  targets: [
    .target(
      name: "CommunityEditorPrototype",
      destinations: .iOS,
      product: .app,
      bundleId: "ly.getfriend.CommunityEditorPrototype",
      deploymentTargets: .iOS("26.0"),
      infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
      sources: ["Sources/**"],
      dependencies: [.package(product: "CommunityEditorFeature")]
    ),
    .target(
      name: "CommunityEditorTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "ly.getfriend.CommunityEditorTests",
      deploymentTargets: .iOS("26.0"),
      infoPlist: .default,
      sources: ["../../Packages/Features/Tests/CommunityMarkdownServiceTests/**", "../../Packages/Features/Tests/CommunityEditorFeatureTests/**", "../../Packages/Features/Tests/CommunityMarkdownFeatureTests/**"],
      dependencies: [.target(name: "CommunityEditorPrototype"), .package(product: "CommunityEditorFeature"), .package(product: "CommunityMarkdownFeature"), .package(product: "CommunityMarkdownService")]
    ),
  ],
  schemes: [
    .scheme(
      name: "CommunityPrototype",
      shared: true,
      buildAction: .buildAction(targets: ["CommunityEditorPrototype"]),
      testAction: .targets(["CommunityEditorTests"]),
      runAction: .runAction(executable: "CommunityEditorPrototype")
    ),
  ]
)
