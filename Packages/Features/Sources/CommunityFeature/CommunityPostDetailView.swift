import CommunityMarkdownFeature
import CommunityService
import Foundation
import SwiftUI

struct CommunityPostDetailView: View {
  @Bindable private var model: CommunityPostDetailViewModel
  @Environment(\.scenePhase) private var scenePhase
  @FocusState private var isReplyFocused: Bool
  @State private var didPosition = false
  @State private var highlightedReplyID: Int64?
  private let avatarURL: (CommunityPost.Owner.Avatar) -> URL
  private let openAuthor: ((CommunityPost.Owner) -> Void)?
  private let currentUser: CommunityPost.Owner?
  private let focusReplyOnAppear: Bool
  private let initialReplyID: Int64?

  init(
    model: CommunityPostDetailViewModel, currentUser: CommunityPost.Owner?,
    avatarURL: @escaping (CommunityPost.Owner.Avatar) -> URL,
    openAuthor: ((CommunityPost.Owner) -> Void)?,
    focusReplyOnAppear: Bool = false,
    initialReplyID: Int64? = nil
  ) {
    self.model = model
    self.currentUser = currentUser
    self.avatarURL = avatarURL
    self.openAuthor = openAuthor
    self.focusReplyOnAppear = focusReplyOnAppear
    self.initialReplyID = initialReplyID
  }

  var body: some View { contentView() }
}

private extension CommunityPostDetailView {
  private func contentView() -> some View {
    discussionView()
      .alert(.postReplyUncertain, isPresented: replyRetryPresented) {
        Button(.postRepliesRetry) { publishReply(confirmedRetry: true) }
        Button(.commonCancel, role: .cancel) {}
      }
      .alert(.postReply, isPresented: Binding(
        get: { model.composer == nil && replyError != nil && !replyRetryPresented.wrappedValue },
        set: { if !$0 { model.sendError = nil; model.replyComposer?.dismissPublicationError() } }
      )) {
        Button(.commonOk, role: .cancel) { model.sendError = nil; model.replyComposer?.dismissPublicationError() }
      } message: {
        if let error = replyError { Text(error) }
      }
      .alert(.postDelete, isPresented: Binding(
        get: { model.mutationError != nil },
        set: { if !$0 { model.mutationError = nil } }
      )) {
        Button(.commonOk, role: .cancel) { model.mutationError = nil }
      } message: {
        if let error = model.mutationError { Text(error) }
      }
  }

  private func discussionView() -> some View {
    scrollView()
      .background(Constants.background)
      .navigationTitle(.postTitle)
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaBar(edge: .bottom) { replyBar() }
      .sheet(item: $model.composer) { CommunityComposerView(model: $0) }
      .sheet(item: $model.editingPost) { CommunityEditView(model: $0) }
      .task { await model.activate() }
      .task(id: highlightedReplyID) { await clearHighlight() }
      .task {
        if focusReplyOnAppear {
          await Task.yield()
          isReplyFocused = true
        }
      }
      .refreshable { await model.load() }
      .onDisappear { model.stop() }
      .onChange(of: scenePhase) {
        if scenePhase != .active && model.composer == nil { Task { await model.saveDraft() } }
      }
  }

  private var replyRetryPresented: Binding<Bool> {
    Binding(
      get: { model.composer == nil && model.replyComposer?.needsRetryConfirmation == true },
      set: { model.replyComposer?.needsRetryConfirmation = $0 })
  }

  private var replyError: LocalizedStringResource? {
    model.sendError ?? model.replyComposer?.publicationError
  }

  private func publishReply(confirmedRetry: Bool = false) {
    guard let composer = model.replyComposer else { return }
    composer.perform { await composer.publish(confirmedRetry: confirmedRetry) }
  }

  private func scrollView() -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: Constants.zero) {
          chainView()
          repliesView()
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: model.loaded) {
        guard model.loaded, !didPosition else { return }
        didPosition = true
        let target = initialReplyID.flatMap { id in
          model.replies.contains(where: { $0.id == id }) ? id : nil
        }
        proxy.scrollTo(target ?? model.post.id, anchor: .top)
        highlightedReplyID = target
      }
      .onChange(of: model.scrollToReplyID) {
        guard let id = model.scrollToReplyID else { return }
        Task { @MainActor in
          await Task.yield()
          withAnimation(.easeOut(duration: Constants.selectionDuration)) {
            proxy.scrollTo(id, anchor: .bottom)
          }
        }
      }
    }
  }

  private func chainView() -> some View {
    VStack(alignment: .leading, spacing: Constants.zero) {
      ancestorsView()
      selectedPostView().id(model.post.id)
    }
  }

  @ViewBuilder
  private func ancestorsView() -> some View {
    ForEach(model.ancestorRows) { ancestor in
      ancestorView(ancestor)
    }
  }

  private func ancestorView(_ item: CommunityFeedPost) -> some View {
    postRow(item)
      .overlay { connectorView() }
  }

  private func selectedPostView() -> some View {
    postLayout(for: model.post) {
      bodyView(for: model.post)
    } reply: {
      model.reply(to: model.post)
    }
  }

  @ViewBuilder
  private func repliesView() -> some View {
    repliesHeaderView()
    if model.isLoading && !model.loaded { loadingView() }
    if let error = model.loadError { errorView(error) { Task { await model.load() } } }
    if model.loaded && model.replies.isEmpty && model.pendingReplies.isEmpty {
      Text(.postRepliesEmpty).foregroundStyle(.secondary).padding(Constants.padding)
    }
    ForEach(model.replyRows) { reply in
      postRow(reply)
        .background(highlightedReplyID == reply.id ? Constants.highlight : .clear)
        .id(reply.id)
      Divider()
    }
    ForEach(model.pendingRows) { reply in
      postRow(reply)
        .id(reply.id)
      Divider()
    }
    paginationView()
  }

  private func repliesHeaderView() -> some View {
    VStack(spacing: Constants.zero) {
      Divider()
      Text(.postRepliesTitle)
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: Constants.repliesHeaderHeight, alignment: .leading)
        .padding(.horizontal, Constants.padding)
      Divider()
    }
  }

  private func connectorView() -> some View {
    Canvas { context, size in
      let start = CGPoint(x: Constants.connectorCenterX, y: Constants.connectorStartY)
      let end = CGPoint(x: Constants.connectorCenterX, y: size.height)
      guard end.y > start.y else { return }
      var path = Path()
      path.move(to: start)
      path.addLine(to: end)
      context.stroke(path, with: .color(Constants.connectorColor),
                     style: StrokeStyle(lineWidth: Constants.connectorWidth, lineCap: .round))
    }
    .allowsHitTesting(false)
  }

  private func postRow(_ item: CommunityFeedPost) -> some View {
    postLayout(for: item.post) {
      CommunityPostContent(content: item.content, expandsInPlace: true) {
        select(item.post)
      }
    } reply: {
      model.reply(to: item.post)
    }
    .contentShape(.rect)
    .onTapGesture { select(item.post) }
    .accessibilityAction(named: .postReadAll) { select(item.post) }
  }

  private func select(_ post: CommunityPost) {
    guard post.id != model.post.id else { return }
    withAnimation(.easeOut(duration: Constants.selectionDuration)) {
      model.select(post)
    }
    Task {
      if !model.loaded { await model.load() }
    }
    Task { await model.restore() }
  }

  private func clearHighlight() async {
    guard highlightedReplyID != nil else { return }
    do { try await Task.sleep(for: .seconds(Constants.highlightDuration)) } catch { return }
    highlightedReplyID = nil
  }

  private func postLayout<Content: View>(
    for post: CommunityPost, @ViewBuilder content: () -> Content,
    reply: @escaping () -> Void
  ) -> some View {
    HStack(alignment: .top, spacing: Constants.avatarSpacing) {
      CommunityAvatar(owner: post.owner, avatarURL: avatarURL)
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
      VStack(alignment: .leading, spacing: Constants.postSpacing) {
        headerView(for: post)
        content()
        CommunityPostFooter(
          owners: post.replyPreviews, avatarURL: avatarURL,
          alignment: .leading, showsReplySymbol: false, reply: reply)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, Constants.padding)
    .padding(.top, Constants.postTopPadding)
    .padding(.bottom, Constants.postBottomPadding)
  }

  private func headerView(for post: CommunityPost) -> some View {
    CommunityPostHeader(
      post: post, openAuthor: openAuthor, canManage: model.canManage(post),
      isDeleting: model.deletingID == post.id, actionsDisabled: model.deletingID != nil,
      edit: { model.edit(post) }, delete: { Task { await model.delete(post) } })
  }

  @ViewBuilder
  private func bodyView(for post: CommunityPost) -> some View {
    if let text = post.text {
      if let content = model.selectedRow?.content,
         content.source == text,
         let excerpt = content.excerpt,
         !excerpt.isTruncated {
        MarkdownPreview(document: excerpt.document, allowsImageViewing: true)
      } else {
        MarkdownPreview(source: text, allowsImageViewing: true)
      }
    } else {
      Label(.postDeleted, systemImage: Constants.delete).foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func paginationView() -> some View {
    if model.isLoadingMore { loadingView() }
    if let error = model.pageError { errorView(error) { Task { await model.loadMore() } } }
    if model.nextID != nil && !model.isLoadingMore && model.pageError == nil {
      Button(.feedLoadMore) { Task { await model.loadMore() } }
        .frame(maxWidth: .infinity).padding(Constants.padding)
    }
  }

  private func loadingView() -> some View {
    ProgressView().frame(maxWidth: .infinity).padding(Constants.padding)
  }

  private func errorView(_ message: LocalizedStringResource, retry: @escaping () -> Void) -> some View {
    VStack(spacing: Constants.spacing) {
      Text(message).foregroundStyle(.secondary)
      Button(.postRepliesRetry, action: retry)
    }
    .frame(maxWidth: .infinity).padding(Constants.padding)
  }

  private func replyBar() -> some View {
    HStack(alignment: .top, spacing: Constants.spacing) {
      CommunityAvatar(owner: currentUser, avatarURL: avatarURL)
        .frame(width: Constants.barAvatarSize, height: Constants.barAvatarSize)
        .frame(width: Constants.controlHeight, height: Constants.controlHeight)
      replyControls()
    }
    .padding(Constants.barPadding)
    .glassEffect(in: .rect(cornerRadius: Constants.barCornerRadius))
    .padding(.horizontal, Constants.padding)
    .padding(.vertical, Constants.barPadding)
  }

  @ViewBuilder
  private func replyControls() -> some View {
    if let composer = model.replyComposer {
      HStack(alignment: .bottom, spacing: Constants.replyControlSpacing) {
        inputView(composer)
        expandButton()
        if !composer.editor.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          sendButton(composer)
        }
      }
      .disabled(!composer.isReady || composer.isPublishing || composer.isPerformingAction)
    }
  }

  @ViewBuilder
  private func inputView(_ composer: CommunityComposerViewModel) -> some View {
    if !composer.isReady {
      ProgressView().frame(maxWidth: .infinity, minHeight: Constants.controlHeight)
    } else if composer.plainText != nil {
      TextField(.postReplyPlaceholder, text: Binding(
        get: { composer.plainText ?? "" }, set: composer.setPlainText), axis: .vertical)
        .focused($isReplyFocused)
        .lineLimit(1...4)
        .frame(maxWidth: .infinity, minHeight: Constants.controlHeight, alignment: .leading)
    } else {
      Button(.postReplyMarkdownDraft) { model.expandEditor() }
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: Constants.controlHeight, alignment: .leading)
    }
  }

  private func expandButton() -> some View {
    Button(.postReplyExpand, systemImage: Constants.expand) { model.expandEditor() }
      .labelStyle(.iconOnly)
      .foregroundStyle(.primary)
      .frame(width: Constants.controlHeight, height: Constants.controlHeight)
      .buttonStyle(.plain)
  }

  private func sendButton(_ composer: CommunityComposerViewModel) -> some View {
    Button { publishReply() } label: {
      if composer.isPublishing { ProgressView() } else { Image(systemName: Constants.send) }
    }
    .accessibilityLabel(.composerPublish)
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .frame(width: Constants.controlHeight, height: Constants.controlHeight)
    .disabled(!composer.canPublish)
  }

}

private enum Constants {
  static let zero: CGFloat = 0
  static let spacing: CGFloat = 10
  static let postSpacing: CGFloat = 4
  static let postTopPadding: CGFloat = 12
  static let postBottomPadding: CGFloat = 8
  static let repliesHeaderHeight: CGFloat = 52
  static let avatarSpacing: CGFloat = 10
  static let avatarSize: CGFloat = 40
  static let barAvatarSize: CGFloat = 40
  static let controlHeight: CGFloat = 44
  static let barCornerRadius: CGFloat = 30
  static let replyControlSpacing: CGFloat = 8
  static let padding: CGFloat = 16
  static let barPadding: CGFloat = 8
  static let connectorWidth: CGFloat = 2
  static let connectorGap: CGFloat = postTopPadding
  static let connectorCenterX: CGFloat = padding + avatarSize / 2
  static let connectorStartY: CGFloat = postTopPadding + avatarSize + connectorGap
  static let connectorColor = Color(uiColor: .separator)
  static let background = Color(uiColor: .systemBackground)
  static let delete = "trash"
  static let expand = "arrow.up.left.and.arrow.down.right"
  static let send = "arrow.up"
  static let selectionDuration = 0.22
  static let highlightDuration = 2.5
  static let highlight = Color.accentColor.opacity(0.12)
}
