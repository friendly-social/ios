import SwiftUI
import Flow

struct ProfileView: View {
    @State private var showSignUpConfirmation = false

    private let viewModel: ProfileViewModel

    init(routeToSignUp: @escaping () -> Void) {
        viewModel = ProfileViewModel(routeToSignUp: routeToSignUp)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack {
                switch viewModel.state {
                case .loading: LoadingView()
                case .ioError: IOErrorView()
                case .success(let user): UserView(user: user)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showSignUpConfirmation = true }) {
                        Image(
                            systemName: "rectangle.portrait.and.arrow.right",
                        )
                    }
                    .confirmationDialog(
                        "profile_sign_out_confirmation",
                        isPresented: $showSignUpConfirmation,
                        titleVisibility: .visible,
                    ) {
                        Button("profile_sign_out_confirm", role: .destructive) {
                            viewModel.signOut()
                        }
                    }
                }
            }
            .onAppear { viewModel.appear() }
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
                Chip(text: interest.string)
            }
        }
    }
}

private struct Chip: View {
    let text: String

    @Environment(\.colorScheme) var colorScheme

    private var pastelColor: Color {
        let lightPastels = [
            Color(red: 1.0, green: 0.8, blue: 0.8),
            Color(red: 0.8, green: 0.9, blue: 1.0),
            Color(red: 0.85, green: 0.95, blue: 0.85),
            Color(red: 1.0, green: 0.9, blue: 0.7),
            Color(red: 0.95, green: 0.8, blue: 1.0),
        ]
        let darkPastels = [
            Color(red: 0.6, green: 0.3, blue: 0.3),
            Color(red: 0.3, green: 0.4, blue: 0.6),
            Color(red: 0.35, green: 0.45, blue: 0.35),
            Color(red: 0.6, green: 0.5, blue: 0.3),
            Color(red: 0.5, green: 0.3, blue: 0.6),
        ]
        let colors = colorScheme == .dark ? darkPastels : lightPastels
        let sum = text.unicodeScalars.reduce(0) { acc, scalar in
            acc + Int(scalar.value)
        }
        let index = abs(sum) % colors.count
        return colors[index]
    }

    var body: some View {
        Button(action: {}) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(pastelColor)
                .foregroundColor(.primary)
                .clipShape(Capsule())
        }
    }
}
