import CommunityMarkdownFeature
import CommunityService
import Foundation
import SwiftUI

public struct CommunityView<ActivityDestination: View>: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable private var model: CommunityViewModel
  @State private var imageLayoutCache = MarkdownImageLayoutCache()
  @Binding private var hidesTabBar: Bool
  private let avatarURL: (CommunityPost.Owner.Avatar) -> URL
  private let openAuthor: ((CommunityPost.Owner) -> Void)?
  private let activityDestination: () -> ActivityDestination

  public init(
    model: CommunityViewModel, avatarURL: @escaping (CommunityPost.Owner.Avatar) -> URL,
    hidesTabBar: Binding<Bool>,
    openAuthor: ((CommunityPost.Owner) -> Void)? = nil,
    @ViewBuilder activityDestination: @escaping () -> ActivityDestination
  ) {
    self.model = model
    self.avatarURL = avatarURL
    self._hidesTabBar = hidesTabBar
    self.openAuthor = openAuthor
    self.activityDestination = activityDestination
  }

  public var body: some View {
    contentView()
  }
}

private extension CommunityView {

  private func contentView() -> some View {
    NavigationStack {
      feedNavigationContent()
        .sheet(item: $model.composer) { composer in
          CommunityComposerView(model: composer)
          .presentationDetents([.large])
        }
        .sheet(item: $model.editingPost) { editor in
          CommunityEditView(model: editor).presentationDetents([.large])
        }
        .alert(
          .postMutationUnconfirmed,
          isPresented: Binding(
            get: { model.mutationError != nil }, set: { if !$0 { model.mutationError = nil } })
        ) {
          Button(.commonOk, role: .cancel) { model.mutationError = nil }
        } message: {
          if let error = model.mutationError { Text(error) }
        }
    }
    .onChange(of: model.destination == nil, initial: true) {
      hidesTabBar = model.destination != nil
    }
    .markdownImageLayoutCache(imageLayoutCache)
  }

  private func feedNavigationContent() -> some View {
    scrollView()
      .transaction { $0.animation = nil }
      .background(Constants.background)
      .navigationTitle(Text(verbatim: "Friendly"))
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(item: $model.destination) { destination in
        switch destination {
        case let .post(route): postDetails(for: route)
        case .activity: activityDestination()
        }
      }
      .toolbar { activityToolbar() }
      .refreshable {
        await model.load()
        await model.refreshActivity()
      }
      .task(id: scenePhase == .active && model.destination == nil) {
        if scenePhase == .active && model.destination == nil { await model.refreshActivity() }
      }
      .task { await model.load() }
      .task { await model.loadProfile() }
      .task { await model.observeDraft() }
      .onDisappear {
        model.stop()
      }
  }

  private func postDetails(for route: CommunityViewModel.PostDetailRoute) -> some View {
    CommunityPostDetailView(
      model: route.model,
      currentUser: model.currentUser, avatarURL: avatarURL, openAuthor: openAuthor,
      focusReplyOnAppear: route.focusReplyOnAppear)
  }

  private func activityToolbar() -> some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button(.communityActivity, systemImage: Constants.activity) {
        model.openActivity()
      }
      .labelStyle(.iconOnly)
      .badge(model.hasNewActivity ? Text(verbatim: "") : nil)
      .accessibilityLabel(Text(model.hasNewActivity ? .communityActivityNew : .communityActivity))
    }
  }

  private func deletePost(_ post: CommunityPost) {
    model.deleteButtonTapped(post)
  }

  @ViewBuilder
  private func postsView() -> some View {
    ForEach(model.feedPosts) { item in
      let post = item.post
      VStack(spacing: Constants.zero) {
        CommunityPostCard(
          post: post, content: item.content, avatarURL: avatarURL, openAuthor: openAuthor,
          canManage: model.showsPostActions(for: post), isDeleting: model.deletingID == post.id,
          actionsDisabled: model.deletingID != nil,
          edit: { model.editButtonTapped(post) },
          delete: { deletePost(post) },
          reply: { model.openDetails(item, focusReply: true) },
          openDetails: { model.openDetails(item) }
        )
        Divider()
      }
    }
  }

  @ViewBuilder
  private func feedView() -> some View {
    LazyVStack(alignment: .leading, spacing: Constants.zero) {
      CommunityComposePrompt(
        owner: model.currentUser, draftState: model.draftState,
        avatarURL: avatarURL, compose: model.compose)
        .disabled(model.deletingID != nil)
      Divider()
      if let notice = model.notice {
        Text(notice).font(.callout).foregroundStyle(Constants.secondary).padding(Constants.padding)
      }
      if let error = model.error {
        Text(error).foregroundStyle(Constants.error).padding(Constants.padding)
      }
      emptyView()
      postsView()
      if model.isLoading {
        ProgressView().frame(maxWidth: .infinity).padding(Constants.padding)
      } else if model.nextID != nil {
        Button(.feedLoadMore) {
          model.loadMoreButtonTapped()
        }
        .frame(maxWidth: .infinity)
        .padding(Constants.padding)
      }
    }
  }

  @ViewBuilder
  private func scrollView() -> some View {
    ScrollView {
      feedView()
    }
  }

  @ViewBuilder
  private func emptyView() -> some View {
    if model.posts.isEmpty && !model.isLoading && model.error == nil {
      ContentUnavailableView(
        .feedEmpty,
        systemImage: Constants.empty,
        description: Text(.feedEmptyHint))
    }
  }
}

private enum Constants {
  static let zero: CGFloat = 0
  static let padding: CGFloat = 16
  static let secondary = Color.secondary
  static let error = Color.red
  static let background = Color(uiColor: .systemBackground)
  static let empty = "text.bubble"
  static let activity = "bell"
}
