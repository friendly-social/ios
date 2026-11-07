import Models
import NetworkQRCodeFeature
import PhotoViewerFeature
import SwiftUI

public struct ProfileView: View {
  @State private var showSignUpConfirmation = false
  @State private var showFriendDeclineConfirmation = false
  @State private var viewModel: ProfileViewModel

  public init(mode: Mode) {
    viewModel = ProfileViewModel(mode: mode)
  }

  @Environment(\.dismiss) private var dismiss

  public var body: some View {
    contentView()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Constants.background)
      .sheet(item: $viewModel.sheetDestination, onDismiss: viewModel.editProfileDismissed) { destination in
        switch destination {
        case .edit:
          if case let .success(profile) = viewModel.state {
            ProfileEditView(profileInfo: profile.info, onComplete: { viewModel.destination = nil },
                          service: viewModel.profileFormService)
          }
        case .invitation: NetworkQRCodeView(onDismiss: { viewModel.destination = nil })
        case .commonFriends, .photo: EmptyView()
        }
      }
      .fullScreenCover(item: $viewModel.photoDestination) { destination in
        if case let .photo(photo) = destination {
          PhotoViewer(
            image: photo.image,
            imageLabel: Text(.profileAvatar),
            sourceFrame: photo.sourceFrame,
            imageSize: photo.imageSize,
            sourceCornerRadius: min(photo.sourceFrame.width, photo.sourceFrame.height) / 2
          )
        }
      }
      .navigationDestination(item: $viewModel.navigationDestination) { destination in
        switch destination {
        case .commonFriends:
          if let friends = viewModel.displayedFriends {
            ProfileFriendsView(friends: friends, selection: viewModel.profileSelection)
          }
        case .edit, .invitation, .photo: EmptyView()
        }
      }
      .toolbar { toolbarContent() }
      .toolbarVisibility(viewModel.enableSignOut ? .automatic : .hidden, for: .tabBar)
      .onAppear { viewModel.appear() }
      .onChange(of: viewModel.shouldDismiss) { _, dismissRequested in
        if dismissRequested { dismiss() }
      }
      .alert(.profileError, isPresented: .constant(viewModel.alertError != nil)) {
        Button(.profileErrorOk) { viewModel.clearAlertError() }
      } message: {
        Text(.profileErrorDecline)
      }
      .refreshable { await viewModel.reload() }
  }

  public enum Mode {
    case selfProfile(SelfProfile)
    case otherProfile(OtherProfile)
  }

  public struct SelfProfile {
    let routeToSignUp: () -> Void

    public init(routeToSignUp: @escaping () -> Void) {
      self.routeToSignUp = routeToSignUp
    }
  }

  public struct OtherProfile {
    let id: UserId
    let accessHash: UserAccessHash

    public init(id: UserId, accessHash: UserAccessHash) {
      self.id = id
      self.accessHash = accessHash
    }
  }
}

private extension ProfileView {
  @ViewBuilder
  private func contentView() -> some View {
    switch viewModel.state {
    case .loading: LoadingView()
    case .ioError: IOErrorView()
    case let .success(user):
      ProfileContentView(model: viewModel, profile: user)
    }
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      if viewModel.enableSignOut {
        Button { viewModel.showInvitation() } label: {
          Label(.profileAddPeople, systemImage: Constants.addPeopleSymbol).labelStyle(.iconOnly)
        }
      }
    }
    ToolbarItemGroup(placement: .primaryAction) {
      if viewModel.enableEdit {
        Button { viewModel.showEditProfile() } label: {
          Image(systemName: Constants.settingsSymbol)
        }
      }
      if viewModel.enableSignOut {
        Button { showSignUpConfirmation = true } label: {
          Image(systemName: Constants.signOutSymbol)
        }
        .confirmationDialog(.profileSignOutConfirmation, isPresented: $showSignUpConfirmation) {
          Button(.profileSignOutConfirm, role: .destructive) { viewModel.signOut() }
        }
      }
      if viewModel.enableRemoveFromFriends {
        Menu {
          Button(role: .destructive) { showFriendDeclineConfirmation = true } label: {
            Label(.profileFriendsDecline, systemImage: Constants.removeFriendSymbol)
          }
        } label: { Image(systemName: Constants.moreSymbol) }
        .confirmationDialog(.profileFriendsDeclineConfirmation, isPresented: $showFriendDeclineConfirmation) {
          Button(.profileFriendsDeclineConfirm, role: .destructive) {
            Task { await viewModel.friendsDecline() }
          }
        }
        .disabled(viewModel.isUpdatingFriendship)
      }
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
      Image(systemName: Constants.connectionErrorSymbol)
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

private enum Constants {
  static let background = Color(uiColor: .systemBackground)
  static let settingsSymbol = "gearshape"
  static let addPeopleSymbol = "person.badge.plus"
  static let signOutSymbol = "rectangle.portrait.and.arrow.right"
  static let removeFriendSymbol = "person.fill.badge.minus"
  static let moreSymbol = "ellipsis"
  static let connectionErrorSymbol = "wifi.slash"
  static let stateIconSize: CGFloat = 50
}
