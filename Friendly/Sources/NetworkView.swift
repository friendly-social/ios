import SwiftUI

struct NetworkView: View {
    private let viewModel: NetworkViewModel = NetworkViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationView {
            ZStack {
                switch viewModel.state {
                case .loading: LoadingView()
                case .ioError: IOErrorView()
                case .success(let friends): NetworkSuccessView(friends: friends)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {}) {
                        Image(systemName: "qrcode")
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

private struct NetworkSuccessView: View {
    let friends: [NetworkViewModel.Friend]

    var body: some View {
        if friends.isEmpty {
            VStack {
                Image(systemName: "person.line.dotted.person")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.secondary)
                Text("network_friends_empty")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                Text("network_friends_scan_qrcode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
            .navigationTitle("network_friends_title")
        }
    }
}

private struct FriendView: View {
    let friend: NetworkViewModel.Friend

    var body: some View {
        HStack {
            AvatarView(
                url: friend.avatarUrl,
                size: 50,
            )
            Text(friend.nickname.string)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
