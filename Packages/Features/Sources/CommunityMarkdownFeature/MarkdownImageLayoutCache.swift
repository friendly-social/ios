import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class MarkdownImageLayoutCache {
  private var ratios: [URL: CGFloat] = [:]

  public init() {}
}

extension MarkdownImageLayoutCache {
  func ratio(for url: URL) -> CGFloat? {
    ratios[url]
  }

  func record(size: CGSize, for url: URL) {
    guard size.width.isFinite, size.height.isFinite,
      size.width > 0, size.height > 0
    else { return }
    let ratio = size.width / size.height
    guard ratio.isFinite, ratio > 0, ratios[url] != ratio else { return }
    ratios[url] = ratio
  }
}

extension EnvironmentValues {
  @Entry var markdownImageLayoutCache: MarkdownImageLayoutCache?
}

public extension View {
  func markdownImageLayoutCache(_ cache: MarkdownImageLayoutCache) -> some View {
    environment(\.markdownImageLayoutCache, cache)
  }
}

struct MarkdownImageLayout: Layout {
  let ratio: CGFloat?
  let maximumHeight: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let ratio, let width = proposal.width, width.isFinite else {
      return subviews.first?.sizeThatFits(
        ProposedViewSize(width: proposal.width, height: maximumHeight)) ?? .zero
    }
    return CGSize(width: width, height: min(width / ratio, maximumHeight))
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    subviews.first?.place(
      at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
      proposal: ProposedViewSize(bounds.size))
  }
}
