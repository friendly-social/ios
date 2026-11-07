import FriendlyUIKit
import NetworkQRCodeFeature
import ProfileFeature
import SwiftUI
import UIKit

public struct NetworkView: View {
  @State private var viewModel: NetworkViewModel

  public init(
    router: Router,
  ) {
    self.viewModel = NetworkViewModel(router: router)
  }

  public var body: some View {
    networkContent()
      .animation(
        .easeInOut(duration: Constants.animationDuration),
        value: viewModel.state.rawValue,
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Constants.background)
      .toolbar { invitationToolbar() }
      .navigationTitle(.networkFriendsTitle)
      .sheet(
        item: $viewModel.destination,
        onDismiss: {
          Task { await viewModel.reload() }
        },
      ) { destination in
        destinationView(destination)
      }
      .task { await viewModel.reload() }
      .navigationDestination(for: NetworkViewModel.Destination.self) { destination in
        destinationView(destination)
      }
      .refreshable { await viewModel.reload() }
  }
}

private extension NetworkView {
  @ViewBuilder
  private func networkContent() -> some View {
    switch viewModel.state {
    case .loading: LoadingView()
    case .ioError: IOErrorView()
    case let .success(friends): NetworkSuccessView(friends: friends)
    }
  }

  @ToolbarContentBuilder
  private func invitationToolbar() -> some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Button(action: viewModel.showInvitation) {
        Label(.networkFriendsAddPeople, systemImage: Constants.addPeopleIcon)
          .labelStyle(.iconOnly)
      }
    }
  }

  @ViewBuilder
  private func destinationView(_ destination: NetworkViewModel.Destination) -> some View {
    switch destination {
    case .invitation:
      NetworkQRCodeView(onDismiss: { viewModel.destination = nil })
    case let .profile(id, accessHash):
      ProfileView(mode: .otherProfile(.init(id: id, accessHash: accessHash)))
    }
  }
}

private struct LoadingView: View {
  var body: some View {
    ProgressView()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct IOErrorView: View {
  var body: some View {
    VStack {
      Image(systemName: Constants.connectionErrorIcon)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: Constants.stateIconSize, height: Constants.stateIconSize)
        .foregroundStyle(.secondary)
      Text(.ioErrorTitle)
        .font(.title2)
        .fontWeight(.bold)
        .padding(.top)
      Text(.ioErrorSubtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct NetworkSuccessView: View {
  let friends: [NetworkViewModel.Friend]

  var body: some View {
    if friends.isEmpty {
      VStack {
        Image(systemName: Constants.emptyNetworkIcon)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: Constants.stateIconSize, height: Constants.stateIconSize)
          .foregroundStyle(.secondary)
        Text(.networkFriendsEmpty)
          .font(.title2)
          .fontWeight(.bold)
          .padding(.top)
        Text(.networkFriendsScanQrcode)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(spacing: Constants.listSpacing) {
          ForEach(friends, id: \.id) { friend in
            FriendView(friend: friend)
          }
        }
        .padding()
        .background(Constants.friendsBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.listCornerRadius))
        .padding()
        Text(.networkFriendsAddHint)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct FriendView: View {
  let friend: NetworkViewModel.Friend

  var body: some View {
    Button(action: friend.onClick) {
      HStack {
        AvatarView(
          url: friend.avatarUrl,
          size: Constants.avatarSize,
        )
        Text(friend.nickname.string)
          .font(.body)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

private enum Constants {
  static let background = Color(uiColor: .systemGroupedBackground)
  static let friendsBackground = Color(uiColor: .secondarySystemGroupedBackground)
  static let connectionErrorIcon = "wifi.slash"
  static let emptyNetworkIcon = "person.line.dotted.person"
  static let animationDuration = 0.3
  static let stateIconSize: CGFloat = 50
  static let listSpacing: CGFloat = 12
  static let listCornerRadius: CGFloat = 20
  static let avatarSize: CGFloat = 50
  static let addPeopleIcon = "person.badge.plus"
}
