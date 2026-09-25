@testable import CommunityMarkdownFeature
import Foundation
import SwiftUI
import Testing
import UIKit

@MainActor
struct MarkdownImageLayoutTests {
  @Test func remembersRatiosAndIgnoresInvalidMeasurements() throws {
    let cache = MarkdownImageLayoutCache()
    let url = try #require(URL(string: "https://example.com/photo.jpg"))
    #expect(cache.ratio(for: url) == nil)
    cache.record(size: CGSize(width: 300, height: 150), for: url)
    #expect(cache.ratio(for: url) == 2)
    cache.record(size: .zero, for: url)
    cache.record(size: CGSize(width: CGFloat.infinity, height: 100), for: url)
    #expect(cache.ratio(for: url) == 2)
    cache.record(size: CGSize(width: 600, height: 300), for: url)
    #expect(cache.ratio(for: url) == 2)
  }

  @Test func cachedLayoutDoesNotDependOnLoadingContent() {
    let loading = UIHostingController(rootView:
      MarkdownImageLayout(ratio: 2, maximumHeight: 320) { ProgressView() })
    let loaded = UIHostingController(rootView:
      MarkdownImageLayout(ratio: 2, maximumHeight: 320) { Color.red })
    let proposal = CGSize(width: 300, height: 1000)
    #expect(loading.sizeThatFits(in: proposal) == CGSize(width: 300, height: 150))
    #expect(loaded.sizeThatFits(in: proposal) == loading.sizeThatFits(in: proposal))
    #expect(loaded.sizeThatFits(in: CGSize(width: 200, height: 1000))
      == CGSize(width: 200, height: 100))
  }

  @Test func portraitLayoutKeepsHeightLimit() {
    let controller = UIHostingController(rootView:
      MarkdownImageLayout(ratio: 0.5, maximumHeight: 320) { Color.red })
    #expect(controller.sizeThatFits(in: CGSize(width: 300, height: 1000))
      == CGSize(width: 300, height: 320))
  }
}
