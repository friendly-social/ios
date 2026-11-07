import ScannerFeature
import SignUpFeature
import SwiftUI
import UIKit

public struct ContentView: View {
  @State private var viewModel: ContentViewModel = ContentViewModel()

  public init() {}

  public var body: some View {
    destinationView
      .animation(.easeInOut(duration: 0.3), value: viewModel.destination)
      .transition(.opacity)
      .onAppear {
        viewModel.appear()
      }
      .onOpenURL { url in
        viewModel.open(url)
      }
      .alert(item: $viewModel.friendLinkAlert) { alert in
        friendLinkAlert(alert)
      }
  }
}

private extension ContentView {
  private var destinationView: some View {
    ZStack {
      destinationContent()
      if viewModel.isProcessingFriendAccess {
        friendAccessOverlay()
      }
    }
  }

  private func friendAccessOverlay() -> some View {
    ProgressView()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(uiColor: .systemBackground), ignoresSafeAreaEdges: .all)
  }

  @ViewBuilder
  private func destinationContent() -> some View {
    switch viewModel.destination {
    case .empty:
      EmptyView()
    case .signUp:
      SignUpView(
        onSignUp: viewModel.onSignUp,
        onEmailLogin: viewModel.onEmailLogin,
        service: viewModel.profileFormService,
      )
    case .main:
      MainView(
        routeToSignUp: viewModel.routeToSignUp,
        route: $viewModel.mainRoute,
      )
    case .qrAddFriend:
      ScanToUseAppView(
        onEmailLogin: viewModel.onEmailLogin,
        onSignOut: viewModel.signOut,
        onSuccess: viewModel.onAddFriendWithQr,
      )
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
