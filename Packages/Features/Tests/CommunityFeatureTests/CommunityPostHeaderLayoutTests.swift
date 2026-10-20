@testable import CommunityFeature
import CommunityService
import CustomDump
import Foundation
import SwiftUI
import Testing
import UIKit

@MainActor struct CommunityPostHeaderLayoutTests {
  @Test(arguments: [DynamicTypeSize.large, .accessibility1])
  func actionControlsDoNotChangeHeaderHeight(size: DynamicTypeSize) {
    let normal = height(canManage: false, isDeleting: false, size: size)
    expectNoDifference(height(canManage: true, isDeleting: false, size: size), normal)
    expectNoDifference(height(canManage: true, isDeleting: true, size: size), normal)
  }
}

private extension CommunityPostHeaderLayoutTests {
  private func height(canManage: Bool, isDeleting: Bool, size: DynamicTypeSize) -> CGFloat {
    let owner = CommunityPost.Owner(id: 7, accessHash: "fixture", nickname: "Author")
    let post = CommunityPost.published(.init(
      descriptor: .init(id: 1, accessHash: "fixture"), text: "Body reference", owner: owner,
      date: Date(timeIntervalSince1970: 0), edited: false))
    let view = CommunityPostHeader(
      post: post, openAuthor: nil, canManage: canManage, isDeleting: isDeleting,
      actionsDisabled: false, edit: {}, delete: {})
      .environment(\.dynamicTypeSize, size)
    return UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 300, height: 1000)).height
  }
}
