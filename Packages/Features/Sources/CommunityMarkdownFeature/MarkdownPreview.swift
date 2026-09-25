import CachedAsyncImage
import CommunityMarkdownService
import Foundation
import SwiftUI

public struct MarkdownPreview: View {
  private let document: MarkdownDocument?
  private let source: String
  private let allowsImageViewing: Bool

  public init(
    source: String,
    allowsImageViewing: Bool = false
  ) {
    self.source = source
    self.allowsImageViewing = allowsImageViewing
    self.document = try? MarkdownDocument(source: source)
  }

  public init(
    document: MarkdownDocument,
    allowsImageViewing: Bool = false
  ) {
    self.source = ""
    self.allowsImageViewing = allowsImageViewing
    self.document = document
  }

  public var body: some View {
    contentView()
  }
}

private extension MarkdownPreview {

  private func contentView() -> some View {
    Group {
      if let document {
        MarkdownBlocksView(blocks: document.blocks)
      } else {
        Text(verbatim: source)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .textSelection(.disabled)
    .environment(\.markdownImageViewingEnabled, allowsImageViewing)
  }
}

private struct MarkdownBlocksView: View {
  let blocks: [MarkdownDocument.Block]
  var body: some View {
    contentView()
  }
}

private extension MarkdownBlocksView {

  @ViewBuilder
  private func contentView() -> some View {
    VStack(alignment: .leading, spacing: Constants.blockSpacing) {
      ForEach(blocks) { block in
        MarkdownBlockView(block: block)
      }
    }
  }
}

private struct MarkdownBlockView: View {
  let block: MarkdownDocument.Block

  var body: some View {
    contentView()
  }
}

private extension MarkdownBlockView {

  @ViewBuilder
  private func contentView() -> some View {
    switch block.kind {
    case let .paragraph(content):
      MarkdownInlineView(content: content)
    case let .heading(level, content):
      MarkdownInlineView(content: content)
        .font(
          level == Constants.titleLevel
            ? .title.bold() : level == Constants.subtitleLevel ? .title2.bold() : .headline
        )
        .accessibilityAddTraits(.isHeader)
    case let .quote(blocks):
      quoteView(blocks)
    case let .list(items):
      listView(items)
    case let .code(language, text):
      codeView(language: language, text: text)
        .padding(Constants.blockPadding)
        .background(.quaternary, in: .rect(cornerRadius: Constants.cornerRadius))
    case let .table(table):
      MarkdownTableView(table: table)
    case .divider:
      Divider()
    case let .unsupported(source):
      unsupportedView(source)
    }
  }

  private func quoteView(_ blocks: [MarkdownDocument.Block]) -> some View {
    MarkdownBlocksView(blocks: blocks)
      .padding(.leading, Constants.blockPadding)
      .overlay(alignment: .leading) {
        RoundedRectangle(cornerRadius: Constants.quoteRadius)
          .fill(.tertiary).frame(width: Constants.quoteWidth)
      }
  }

  @ViewBuilder
  private func listView(_ items: [MarkdownDocument.ListItem]) -> some View {
    VStack(alignment: .leading, spacing: Constants.itemSpacing) {
      ForEach(items) { item in
        listItemView(item)
      }
    }
  }

  @ViewBuilder
  private func listItemView(_ item: MarkdownDocument.ListItem) -> some View {
    HStack(alignment: .top, spacing: Constants.itemSpacing) {
      if let checked = item.checked {
        Image(systemName: checked ? Constants.checked : Constants.unchecked)
          .accessibilityLabel(
            checked
              ? .markdownChecked
              : .markdownUnchecked)
      } else {
        Text(item.marker).foregroundStyle(.secondary)
      }
      MarkdownBlocksView(blocks: item.blocks)
    }
  }

  @ViewBuilder
  private func codeView(language: String?, text: String) -> some View {
    VStack(alignment: .leading, spacing: Constants.itemSpacing) {
      if let language, !language.isEmpty {
        Text(language).font(.caption).foregroundStyle(.secondary)
      }
      ScrollView(.horizontal) {
        Text(verbatim: text).font(.body.monospaced()).fixedSize(horizontal: true, vertical: false)
      }
    }
  }

  @ViewBuilder
  private func unsupportedView(_ source: String) -> some View {
    VStack(alignment: .leading, spacing: Constants.captionSpacing) {
      Text(.markdownHtml).font(
        .caption
      ).foregroundStyle(.secondary)
      Text(verbatim: source).font(.body.monospaced())
    }
  }
}

private struct MarkdownInlineView: View {
  let content: [MarkdownDocument.Inline]

  var body: some View {
    contentView()
  }
}

private extension MarkdownInlineView {

  @ViewBuilder
  private func contentView() -> some View {
    VStack(alignment: .leading, spacing: Constants.itemSpacing) {
      ForEach(content) { inline in
        inlineView(inline)
      }
    }
  }

  @ViewBuilder
  private func inlineView(_ inline: MarkdownDocument.Inline) -> some View {
    switch inline.kind {
    case let .text(text):
      Text(text).fixedSize(horizontal: false, vertical: true)
    case let .image(url, alt):
      MarkdownImageView(url: url, alt: alt)
    }
  }
}

private struct MarkdownImageView: View {
  @State private var sourceFrame = CGRect.zero
  @Environment(\.markdownImageViewingEnabled) private var allowsImageViewing
  @Environment(\.markdownImageLayoutCache) private var layoutCache
  @State private var selectedImage: PresentedImage?
  let url: URL?
  let alt: String

  private struct PresentedImage: Identifiable {
    let id: URL
    let image: Image
    let sourceFrame: CGRect
  }

  var body: some View {
    contentView()
  }
}

private extension MarkdownImageView {
  @ViewBuilder
  private func contentView() -> some View {
    Group {
      if let url {
        MarkdownImageLayout(ratio: layoutCache?.ratio(for: url), maximumHeight: Constants.imageHeight) {
          CachedAsyncImage(url: url) { phase in
            imagePhaseView(phase)
          }
        }
        .frame(maxHeight: Constants.imageHeight)
        .accessibilityLabel(
          alt.isEmpty ? Text(.markdownImage) : Text(alt))
      } else {
        Label { alt.isEmpty ? Text(.markdownImageUnavailable) : Text(alt) } icon: { Image(systemName: Constants.image) }
        .frame(maxWidth: .infinity, minHeight: Constants.emptyImageHeight)
      }
    }
    .frame(maxWidth: .infinity)
    .background(.quaternary, in: .rect(cornerRadius: Constants.cornerRadius))
    .fullScreenCover(item: $selectedImage) { selected in
      MarkdownPhotoViewer(image: selected.image, alt: alt, sourceFrame: selected.sourceFrame)
    }
  }

  @ViewBuilder
  private func imagePhaseView(_ phase: AsyncImagePhase) -> some View {
    switch phase {
    case let .success(image):
      if allowsImageViewing, let url {
        Button {
          var transaction = Transaction(animation: nil)
          transaction.disablesAnimations = true
          withTransaction(transaction) {
            selectedImage = PresentedImage(id: url, image: image, sourceFrame: sourceFrame)
          }
        } label: {
          loadedImageView(image)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sourceFrame = $0 }
            .opacity(selectedImage == nil ? Constants.visible : Constants.hidden)
        }
        .buttonStyle(.plain)
        .accessibilityHint(.markdownOpenImage)
      } else {
        loadedImageView(image)
      }
    case .failure:
      Label { alt.isEmpty ? Text(.markdownImageUnavailable) : Text(alt) } icon: { Image(systemName: Constants.imageError) }
    default:
      ProgressView().frame(
        maxWidth: .infinity,
        minHeight: url.flatMap { layoutCache?.ratio(for: $0) } == nil ? Constants.loadingHeight : nil)
    }
  }

  private func loadedImageView(_ image: Image) -> some View {
    image.resizable().scaledToFit()
      .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
        if let url {
          layoutCache?.record(size: size, for: url)
        }
      }
  }
}

private struct MarkdownTableView: View {
  let table: MarkdownDocument.Table

  var body: some View {
    contentView()
  }
}

private extension MarkdownTableView {

  @ViewBuilder
  private func contentView() -> some View {
    ScrollView(.horizontal) {
      tableGridView()
        .background(Constants.tableBackground, in: .rect(cornerRadius: Constants.cornerRadius))
        .clipShape(.rect(cornerRadius: Constants.cornerRadius))
    }
  }

  private func horizontalAlignment(at index: Int) -> HorizontalAlignment {
    guard table.alignments.indices.contains(index) else { return .leading }
    switch table.alignments[index] {
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    }
  }

  private func alignment(at index: Int) -> Alignment {
    Alignment(horizontal: horizontalAlignment(at: index), vertical: .top)
  }

  @ViewBuilder
  private func tableGridView() -> some View {
    Grid(alignment: .topLeading, horizontalSpacing: Constants.zero, verticalSpacing: Constants.zero)
    {
      ForEach(table.rows) { row in
        if row.id != table.rows.first?.id {
          Divider()
            .gridCellUnsizedAxes(.horizontal)
        }
        GridRow(alignment: .top) {
          ForEach(Array(row.cells.enumerated()), id: \.offset) { index, content in
            MarkdownInlineView(content: content)
              .fontWeight(row.id == Constants.headerRow ? .semibold : .regular)
              .frame(
                minWidth: Constants.cellMinWidth, maxWidth: Constants.cellMaxWidth,
                alignment: alignment(at: index)
              )
              .padding(Constants.cellPadding)
              .background {
                Rectangle().fill(
                  row.id == Constants.headerRow ? Constants.headerBackground : .clear)
              }
              .gridColumnAlignment(horizontalAlignment(at: index))
          }
        }
      }
    }
  }
}

private extension EnvironmentValues {
  @Entry var markdownImageViewingEnabled = false
}

private enum Constants {
  static let visible: Double = 1
  static let hidden: Double = 0
  static let zero: CGFloat = 0
  static let blockSpacing: CGFloat = 14
  static let itemSpacing: CGFloat = 8
  static let captionSpacing: CGFloat = 4
  static let blockPadding: CGFloat = 14
  static let cellPadding: CGFloat = 12
  static let cornerRadius: CGFloat = 12
  static let quoteRadius: CGFloat = 2
  static let quoteWidth: CGFloat = 3
  static let loadingHeight: CGFloat = 120
  static let imageHeight: CGFloat = 320
  static let emptyImageHeight: CGFloat = 100
  static let cellMinWidth: CGFloat = 80
  static let cellMaxWidth: CGFloat = 220
  static let headerRow = 0
  static let titleLevel = 1
  static let subtitleLevel = 2
  static let headerBackground = Color.primary.opacity(0.06)
  static let tableBackground = Color.primary.opacity(0.04)
  static let checked = "checkmark.square"
  static let unchecked = "square"
  static let imageError = "photo.badge.exclamationmark"
  static let image = "photo"
}
