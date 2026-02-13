import SwiftUI

struct ContentView: View {
    @State private var viewModel: ContentViewModel = ContentViewModel()

    var body: some View {
        ZStack {
            switch viewModel.destination {
            case .empty:
                EmptyView()
            case .signUp:
                SignUpView(onComplete: viewModel.onSignUp)
            case .main:
                MainView(
                    routeToSignUp: viewModel.routeToSignUp,
                    addFriend: $viewModel.addFriend,
                )
            case .qrAddFriend:
                ScanToUseAppView(isBlocked: true) { viewModel.onAddFriendWithQr() }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.destination)
        .transition(.opacity)
        .onAppear {
            viewModel.appear()
        }
        .onOpenURL { url in
            guard let deeplink = Deeplink.of(url: url) else { return }
            switch deeplink {
                case let .addFriend(id, token):
                    viewModel.onAddFriend(id: id, token: token)
            }
        }
    }
}
