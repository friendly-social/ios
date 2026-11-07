import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class MarkdownImageLayoutCache {
  private var sizes: [URL: CGSize] = [:]

  public init() {}
}

extension MarkdownImageLayoutCache {
  func size(for url: URL) -> CGSize? {
    sizes[url]
  }

  func record(size: CGSize, for url: URL) {
    guard size.width.isFinite, size.height.isFinite,
      size.width > 0, size.height > 0, sizes[url] != size
    else { return }
    sizes[url] = size
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
  let intrinsicSize: CGSize?
  let maximumHeight: CGFloat
  var width: Double? = nil
  var height: Double? = nil

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let size = requestedSize else {
      return subviews.first?.sizeThatFits(
        ProposedViewSize(width: proposal.width, height: maximumHeight)) ?? .zero
    }
    let availableWidth = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? size.width
    let scale = min(1, availableWidth / size.width, maximumHeight / size.height)
    return CGSize(width: size.width * scale, height: size.height * scale)
  }


  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    subviews.first?.place(
      at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
      proposal: ProposedViewSize(bounds.size))
  }
}

private extension MarkdownImageLayout {
  var requestedSize: CGSize? {
    let requestedWidth = width.flatMap { $0.isFinite && $0 > 0 ? CGFloat($0) : nil }
    let requestedHeight = height.flatMap { $0.isFinite && $0 > 0 ? CGFloat($0) : nil }
    if let requestedWidth, let requestedHeight { return CGSize(width: requestedWidth, height: requestedHeight) }
    guard let intrinsic = intrinsicSize,
      intrinsic.width.isFinite, intrinsic.height.isFinite,
      intrinsic.width > 0, intrinsic.height > 0 else { return nil }
    let ratio = intrinsic.width / intrinsic.height
    return CGSize(
      width: requestedWidth ?? requestedHeight.map { $0 * ratio } ?? intrinsic.width,
      height: requestedHeight ?? requestedWidth.map { $0 / ratio } ?? intrinsic.height)
  }
}
