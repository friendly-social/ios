import SwiftUI

struct ContentView: View {
    @State private var viewModel: ContentViewModel = ContentViewModel()

    var body: some View {
        destinationView
            .animation(.easeInOut(duration: 0.3), value: viewModel.destination)
            .transition(.opacity)
            .onAppear {
                viewModel.appear()
            }
            .onOpenURL { url in
                guard let deeplink = Deeplink.parseOf(url: url) else {
                    viewModel.onInvalidFriendLink()
                    return
                }
                switch deeplink {
                case let .addFriend(id, token):
                    viewModel.onAddFriend(id: id, token: token)
                }
            }
            .alert(item: $viewModel.friendLinkAlert) { alert in
                friendLinkAlert(alert)
            }
    }

    private var destinationView: some View {
        ZStack {
            switch viewModel.destination {
            case .empty:
                EmptyView()
            case .signUp:
                SignUpView(
                    onSignUp: viewModel.onSignUp,
                    onEmailLogin: viewModel.onEmailLogin,
                )
            case .main:
                MainView(
                    routeToSignUp: viewModel.routeToSignUp,
                    route: $viewModel.mainRoute,
                )
            case .qrAddFriend:
                ScanToUseAppView(
                    isBlocked: true,
                    onEmailLogin: viewModel.onEmailLogin,
                    onSuccess: viewModel.onAddFriendWithQr,
                )
            }

            if viewModel.isProcessingFriendAccess {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func friendLinkAlert(
        _ alert: ContentViewModel.FriendLinkAlert,
    ) -> Alert {
        switch alert {
        case .authenticationRequired, .alreadyProcessing, .invalidInvite:
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(.buttonBaseClose)),
            )
        case .retryInvite:
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .default(Text(.friendLinkRetryButton)) {
                    viewModel.retryFriendLink()
                },
                secondaryButton: .cancel(Text(.friendLinkCancelButton)) {
                    viewModel.cancelFriendLink()
                },
            )
        case .retryReconciliation:
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .default(Text(.friendLinkRetryButton)) {
                    viewModel.retryFriendAccessReconciliation()
                },
                secondaryButton: .cancel(Text(.friendLinkCancelButton)),
            )
        }
    }
}
