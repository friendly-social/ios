import CommunityMarkdownFeature
import Flow
import FriendlyUIKit
import Models
import ProfileService
import SwiftUI

struct ProfileContentView: View {
  let model: ProfileViewModel
  let profile: LoadedProfile
  @Environment(\.openURL) private var openURL

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Constants.spacing) {
        headerView()
        if case let .other(friendship, _) = profile.relationship { friendshipView(friendship) }
        Divider()
        aboutView()
        if model.enableSignOut {
          Divider()
          ownFriendsView()
        } else if let preview = model.commonFriendsPreview {
          Divider()
          friendsView(preview, isOwn: false)
        }
      }
      .padding()
    }
  }
}

private extension ProfileContentView {
  private func headerView() -> some View {
    HStack(spacing: Constants.spacing) {
      AvatarView(
        url: profile.info.avatarUrl, size: Constants.avatarSize, openLabel: .profileOpenAvatar,
        isPresented: model.photoDestination != nil
      ) { image, imageSize, sourceFrame in
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { model.showAvatar(image, imageSize: imageSize, sourceFrame: sourceFrame) }
      }
      VStack(alignment: .leading, spacing: Constants.smallSpacing) {
        Text(profile.info.nickname.string).font(.title2.bold())
        socialLinkView()
      }
      Spacer(minLength: Constants.minimumSpacing)
    }
  }

  @ViewBuilder
  private func socialLinkView() -> some View {
    if let url = model.socialLinkDestination {
      Button { openURL(url) } label: {
        HStack(spacing: Constants.smallSpacing) {
          Text(url.absoluteString).lineLimit(Constants.socialLinkLineLimit)
          Image(systemName: Constants.linkSymbol)
        }
        .font(.subheadline)
      }
    }
  }

  @ViewBuilder
  private func friendshipView(_ friendship: Friendship) -> some View {
    switch friendship {
    case .friends: EmptyView()
    case .incomingRequest: friendshipButton(.profileAcceptFriend)
    case .outgoingRequest: friendshipButton(.profileRequestSent).disabled(true)
    case .outgoingDecline, .none: friendshipButton(.profileAddFriend)
    }
  }

  private func friendshipButton(_ title: LocalizedStringResource) -> some View {
    Button { Task { await model.requestFriend() } } label: {
      Text(title).frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .disabled(model.isUpdatingFriendship)
  }

  private func aboutView() -> some View {
    VStack(alignment: .leading, spacing: Constants.smallSpacing) {
      Text(.profileAbout).font(.headline)
      if let document = model.descriptionDocument {
        MarkdownPreview(document: document).font(.subheadline).foregroundStyle(.primary)
      } else {
        Text(profile.info.description.string).foregroundStyle(.primary)
      }
      HFlow(horizontalAlignment: .leading, verticalAlignment: .top) {
        ForEach(profile.info.interests, id: \.string) { interest in
          ChipView(text: interest.string)
        }
      }
    }
  }

  @ViewBuilder
  private func ownFriendsView() -> some View {
    switch model.friendsState {
    case .loading: ProgressView().frame(maxWidth: .infinity)
    case .failed:
      VStack(alignment: .leading, spacing: Constants.smallSpacing) {
        Text(.profileFriends).font(.headline)
        Text(.profileFriendsLoadError).foregroundStyle(.secondary)
        Button(.profileFriendsRetry) { Task { await model.loadFriends() } }
      }
    case let .loaded(friends):
      if friends.isEmpty {
        VStack(alignment: .leading, spacing: Constants.smallSpacing) {
          Text(.profileFriends).font(.headline)
          Text(.profileFriendsEmpty).foregroundStyle(.secondary)
        }
      } else if let preview = model.commonFriendsPreview {
        friendsView(preview, isOwn: true)
      }
      if model.friendsRefreshFailed { friendsRefreshError() }
    }
  }

  private func friendsRefreshError() -> some View {
    VStack(alignment: .leading, spacing: Constants.smallSpacing) {
      Text(.profileFriendsLoadError).foregroundStyle(.secondary)
      Button(.profileFriendsRetry) { Task { await model.loadFriends() } }
    }
  }

  private func friendsView(_ preview: FriendsPreview, isOwn: Bool) -> some View {
    VStack(alignment: .leading, spacing: Constants.spacing) {
      HStack {
        Text(isOwn ? .profileFriends : .profileCommonFriends).font(.headline)
        Spacer()
        Button(.profileSeeAll) { model.showProfileFriends() }
      }
      Button { model.showProfileFriends() } label: {
        friendsRowView(preview)
      }
      .buttonStyle(.plain)
    }
  }

  private func friendsRowView(_ preview: FriendsPreview) -> some View {
    HStack(spacing: Constants.smallSpacing) {
      FriendsAvatarsView(preview: preview)
      Text(preview.names).foregroundStyle(.primary).lineLimit(Constants.friendsNamesLineLimit)
      Spacer(minLength: Constants.minimumSpacing)
      Image(systemName: Constants.chevronSymbol).foregroundStyle(.secondary)
    }
  }
}

private enum Constants {
  static let avatarSize: CGFloat = 76
  static let spacing: CGFloat = 16
  static let smallSpacing: CGFloat = 8
  static let linkSymbol = "arrow.up.right"
  static let chevronSymbol = "chevron.right"
  static let minimumSpacing: CGFloat = 0
  static let socialLinkLineLimit = 1
  static let friendsNamesLineLimit = 2
}
