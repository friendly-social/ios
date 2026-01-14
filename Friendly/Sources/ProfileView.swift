import SwiftUI
import Flow

struct ProfileView: View {
    @State private var showSignUpConfirmation = false
    @State private var showFriendDeclineConfirmation = false
    @State private var viewModel: ProfileViewModel

    @Environment(\.openURL) private var openUrl

    init(
        router: Router,
        mode: Mode,
    ) {
        viewModel = ProfileViewModel(router: router, mode: mode)
    }

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .loading: LoadingView()
            case .ioError: IOErrorView()
            case .success(let user): UserView(user: user)
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: viewModel.state.rawValue,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar(content: {
            let showLink = switch viewModel.state {
                case .success(let success): success.socialUrl != nil
                default: false
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if showLink {
                    Button {
                        openUrl(viewModel.success.socialUrl!)
                    } label: {
                        Image(systemName: "link")
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
                        "profile_sign_out_confirmation",
                        isPresented: $showSignUpConfirmation,
                        titleVisibility: .visible,
                    ) {
                        Button(
                            "profile_sign_out_confirm",
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
                                "profile_friends_decline",
                                systemImage: "person.fill.badge.minus",
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                    }
                    .confirmationDialog(
                        "profile_friends_decline_confirmation",
                        isPresented: $showFriendDeclineConfirmation,
                        titleVisibility: .visible,
                    ) {
                        Button(
                            "profile_friends_decline_confirm",
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
            "profile_error",
            isPresented: .constant(viewModel.alertError != nil),
        ) {
            Button("profile_error_ok") {
                viewModel.clearAlertError()
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            if let error = viewModel.alertError {
                let string: LocalizedStringKey = switch error {
                case .decline: "profile_error_decline"
                }
                Text(string)
            }
        }
        .refreshable { await viewModel.reload() }
    }

    enum Mode {
        case selfProfile(SelfProfile)
        case otherProfile(OtherProfile)
    }

    struct SelfProfile {
        let routeToSignUp: () -> Void
    }

    struct OtherProfile {
        let id: UserId
        let accessHash: UserAccessHash
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
            Text("io_error_title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            Text("io_error_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UserView: View {
    let user: ProfileViewModel.Success

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
    let user: ProfileViewModel.Success

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
