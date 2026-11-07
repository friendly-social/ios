import FriendlyUIKit
import Models
import ProfileService
import SwiftUI

public struct ProfileFriendsView: View {
  @State private var model: ProfileFriendsViewModel

  public init(friends: [FriendSummary], selection: ProfileSelection) {
    _model = State(initialValue: ProfileFriendsViewModel(friends: friends, selection: selection))
  }

  public var body: some View {
    ScrollView {
      if model.refreshFailed {
        VStack {
          Text(.profileFriendsLoadError).foregroundStyle(.secondary)
          Button(.profileFriendsRetry) { Task { await model.reload() } }
        }
        .padding()
      }
      if model.friends.isEmpty {
        Text(model.isOwn ? .profileFriendsEmpty : .profileCommonFriendsEmpty)
          .foregroundStyle(.secondary).padding()
      } else {
        FriendsListView(
          friends: model.friends, nickname: { $0.nickname.string }, avatarURL: { $0.avatarURL },
          onSelect: model.showProfile)
      }
    }
    .background(Constants.background)
    .navigationTitle(model.isOwn ? .profileFriends : .profileCommonFriends)
    .task { await model.reload() }
    .navigationDestination(item: $model.destination) { destination in
      switch destination {
      case let .profile(id, accessHash):
        ProfileView(mode: .otherProfile(.init(id: id, accessHash: accessHash)))
      }
    }
  }
}

private enum Constants {
  static let background = Color(uiColor: .systemGroupedBackground)
}
