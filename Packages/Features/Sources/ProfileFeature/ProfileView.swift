import FriendlyUIKit
import Flow
import Models
import SwiftUI

public struct ProfileView: View {
    @State private var showSignUpConfirmation = false
    @State private var showFriendDeclineConfirmation = false
    @State private var viewModel: ProfileViewModel

    @Environment(\.openURL) private var openUrl

    public init(
        router: Router,
        mode: Mode,
    ) {
        viewModel = ProfileViewModel(router: router, mode: mode)
    }

    public var body: some View {
        ZStack {
            switch viewModel.state {
            case .loading: LoadingView()
            case .ioError: IOErrorView()
            case let .success(user): UserView(user: user)
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: viewModel.state.rawValue,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(
            isPresented: $viewModel.shouldEditProfile,
            onDismiss: {
                viewModel.editProfileDismissed()
            },
        ) {
            let profileInfo: ProfileInfo? = switch viewModel.state {
            case let .success(success): success
            default: nil
            }
            if let profileInfo {
                ProfileEditView(
                    profileInfo: profileInfo,
                    onComplete: {
                        viewModel.shouldEditProfile = false
                    },
                    service: viewModel.profileFormService
                )
            }
        }
        .toolbar(content: {
            let showLink = viewModel.socialLinkDestination != nil
            let showEdit: Bool = switch viewModel.state {
            case .success: viewModel.enableSignOut
            default: false
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if showEdit {
                    Button {
                        viewModel.showEditProfile()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.headline)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                if showLink {
                    Button {
                        if let destination = viewModel.socialLinkDestination {
                            openUrl(destination)
                        }
                    } label: {
                        Image(systemName: "paperplane")
                            .font(.headline)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                if viewModel.enableSignOut {
                    Button(action: { showSignUpConfirmation = true }) {
                        let systemName =
                            "rectangle.portrait.and.arrow.right"
                        Image(systemName: systemName)
                            .font(.headline)
                    }
                    .confirmationDialog(
                        .profileSignOutConfirmation,
                        isPresented: $showSignUpConfirmation,
                        titleVisibility: .visible,
                    ) {
                        Button(
                            .profileSignOutConfirm,
                            role: .destructive,
                        ) {
                            viewModel.signOut()
                        }
                    }
                }
                if viewModel.enableRemoveFromFriends {
                    Menu {
                        Button(action: {
                            showFriendDeclineConfirmation = true
                        }) {
                            Label(
                                .profileFriendsDecline,
                                systemImage: "person.fill.badge.minus",
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                    }
                    .confirmationDialog(
                        .profileFriendsDeclineConfirmation,
                        isPresented: $showFriendDeclineConfirmation,
                        titleVisibility: .visible,
                    ) {
                        Button(
                            .profileFriendsDeclineConfirm,
                            role: .destructive,
                        ) {
                            viewModel.friendsDecline()
                        }
                    }
                }
            }
        })
        .onAppear { viewModel.appear() }
        .alert(
            .profileError,
            isPresented: .constant(viewModel.alertError != nil),
        ) {
            Button(.profileErrorOk) {
                viewModel.clearAlertError()
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            if let error = viewModel.alertError {
                let string: LocalizedStringResource = switch error {
                case .decline: .profileErrorDecline
                }
                Text(string)
            }
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

private struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct IOErrorView: View {
    var body: some View {
        VStack {
            Image(systemName: "wifi.slash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
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

private struct UserView: View {
    let user: ProfileInfo

    var body: some View {
        ScrollView {
            VStack {
                AvatarView(url: user.avatarUrl, size: 150)
                    .padding(.horizontal)
                Details(user: user)
                    .padding(.horizontal)
            }
        }
    }
}

private struct Details: View {
    let user: ProfileInfo

    var body: some View {
        VStack(spacing: 0) {
            Text(user.nickname.string)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 5)
                .padding(.bottom, 10)
            if !user.interests.isEmpty {
                Interests(interests: user.interests)
                    .padding(.bottom, 10)
            }
            if !user.description.string.isEmpty {
                let color = Color(uiColor: .secondarySystemGroupedBackground)
                Text(user.description.string)
                    .font(.subheadline)
                    .padding()
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

private struct Interests: View {
    let interests: [Interest]

    var body: some View {
        HFlow(horizontalAlignment: .center, verticalAlignment: .top) {
            ForEach(interests, id: \.string) { interest in
                ChipView(text: interest.string)
            }
        }
    }
}
