import FriendlyUIKit
import NetworkQRCodeFeature
import ProfileFeature
import ScannerFeature
import SwiftUI

public struct NetworkView: View {
    @State private var viewModel: NetworkViewModel

    public init(
        router: Router,
    ) {
        self.viewModel = NetworkViewModel(router: router)
    }

    public var body: some View {
        ZStack {
            switch viewModel.state {
            case .loading: LoadingView()
            case .ioError: IOErrorView()
            case let .success(friends): NetworkSuccessView(friends: friends)
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: viewModel.state.rawValue,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(
                    action: { viewModel.showQRCode() },
                ) {
                    Image(systemName: "qrcode")
                }
                Button(
                    action: { viewModel.findQRCode() },
                ) {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
        }
        .navigationTitle(.networkFriendsTitle)
        .sheet(
            isPresented: $viewModel.shouldShowQRCode,
        ) {
            NetworkQRCodeView(
                onDismiss: { viewModel.shouldShowQRCode = false },
            )
        }
        .sheet(
            isPresented: $viewModel.shouldFindQRCode,
        ) {
            ScanToUseAppView(isBlocked: false) {
                viewModel.shouldFindQRCode = false
            }
        }
        .task { await viewModel.reload() }
        .navigationDestination(
            for: NetworkViewModel.ProfileDestination.self,
        ) { destination in
            let profile = ProfileView.OtherProfile(
                id: destination.id,
                accessHash: destination.accessHash,
            )
            ProfileView(
                router: viewModel.router,
                mode: .otherProfile(profile),
            )
        }
        .refreshable { await viewModel.reload() }
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

private struct NetworkSuccessView: View {
    let friends: [NetworkViewModel.Friend]

    var body: some View {
        if friends.isEmpty {
            ZStack {
                VStack {
                    Image(systemName: "person.line.dotted.person")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
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
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(friends, id: \.id) { friend in
                        FriendView(friend: friend)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
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
                    size: 50,
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
