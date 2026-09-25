import CommunityMarkdownFeature
import Foundation
import SwiftUI

struct CommunityPostContent: View {
  let content: CommunityFeedPost.Content
  let expandsInPlace: Bool
  let openDetails: () -> Void
  @State private var isExpanded = false

  var body: some View {
    contentView()
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private extension CommunityPostContent {
  @ViewBuilder
  private func contentView() -> some View {
    if let text = content.source {
      excerptView(for: text)
    } else {
      deletedView()
    }
  }

  @ViewBuilder
  private func excerptView(for source: String) -> some View {
    if isExpanded {
      MarkdownPreview(source: source, allowsImageViewing: true)
    } else if let excerpt = content.excerpt {
      VStack(alignment: .leading, spacing: Constants.spacing) {
        MarkdownPreview(
          document: excerpt.document,
          allowsImageViewing: true
        )
        if excerpt.isTruncated { readMoreButton() }
      }
    } else {
      Text(verbatim: source)
    }
  }

  @ViewBuilder
  private func readMoreButton() -> some View {
    if expandsInPlace {
      readMoreAction()
        .highPriorityGesture(TapGesture().onEnded { isExpanded = true })
    } else {
      readMoreAction()
    }
  }

  private func readMoreAction() -> some View {
    Button(.postReadAll) {
      if expandsInPlace { isExpanded = true } else { openDetails() }
    }
      .font(.subheadline)
      .foregroundStyle(Constants.secondary)
      .frame(minHeight: Constants.touchTarget, alignment: .leading)
      .contentShape(.rect)
      .buttonStyle(.plain)
  }

  private func deletedView() -> some View {
    Label(.postDeleted, systemImage: Constants.delete)
      .foregroundStyle(Constants.secondary)
  }

}

private enum Constants {
  static let spacing: CGFloat = 0
  static let touchTarget: CGFloat = 44
  static let secondary = Color.secondary
  static let delete = "trash"
}
