import CommunityFeature
import ProfileFeature
import ScannerFeature
import SignUpFeature
import SwiftUI
import UIKit

struct AppView: View {
  @State private var viewModel: AppViewModel = AppViewModel()
  private let notificationResponses: NotificationResponseStore

  init(notificationResponses: NotificationResponseStore) {
    self.notificationResponses = notificationResponses
  }

  var body: some View {
    destinationView
      .animation(.easeInOut(duration: 0.3), value: viewModel.screen)
      .transition(.opacity)
      .onAppear {
        viewModel.appear()
      }
      .onOpenURL { url in
        viewModel.open(url)
      }
      .onChange(of: notificationResponses.selection, initial: true) {
        viewModel.openNotification(notificationResponses.consume())
      }
      .alert(item: $viewModel.friendLinkAlert) { alert in
        friendLinkAlert(alert)
      }
  }
}

private extension AppView {
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
    switch viewModel.screen {
    case .empty:
      EmptyView()
    case .signUp:
      SignUpView(
        onSignUp: viewModel.onSignUp,
        onEmailLogin: viewModel.onEmailLogin,
        service: viewModel.profileFormService,
      )
    case .main:
      mainView()
    case .qrAddFriend:
      ScanToUseAppView(
        onEmailLogin: viewModel.onEmailLogin,
        onSignOut: viewModel.signOut,
        onSuccess: viewModel.onAddFriendWithQr,
      )
    }
  }

  private func mainView() -> some View {
    MainView(
      routeToSignUp: viewModel.routeToSignUp,
      route: $viewModel.mainRoute,
      destination: $viewModel.destination,
      onOpenNotification: viewModel.showNotification
    ) { destination in
      switch destination {
      case let .notification(notification):
        notificationContent(id: notification.id)
          .id(notification.id)
          .task { await viewModel.loadNotification(id: notification.id) }
          .toolbar(.hidden, for: .tabBar)
      }
    }
  }

  private func friendLinkAlert(_ alert: AppViewModel.FriendLinkAlert) -> Alert {
    switch alert {
    case .authenticationRequired, .alreadyProcessing, .invalidInvite:
      Alert(
        title: Text(alert.title),
        message: Text(alert.message),
        dismissButton: .default(Text(.buttonBaseClose))
      )
    case .retryInvite:
      retryInviteAlert(alert)
    case .retryReconciliation:
      retryReconciliationAlert(alert)
    }
  }

  private func retryInviteAlert(_ alert: AppViewModel.FriendLinkAlert) -> Alert {
    Alert(
      title: Text(alert.title),
      message: Text(alert.message),
      primaryButton: .default(Text(.friendLinkRetryButton)) {
        viewModel.retryFriendLink()
      },
      secondaryButton: .cancel(Text(.friendLinkCancelButton)) {
        viewModel.cancelFriendLink()
      }
    )
  }

  private func retryReconciliationAlert(_ alert: AppViewModel.FriendLinkAlert) -> Alert {
    Alert(
      title: Text(alert.title),
      message: Text(alert.message),
      primaryButton: .default(Text(.friendLinkRetryButton)) {
        viewModel.retryFriendAccessReconciliation()
      },
      secondaryButton: .cancel(Text(.friendLinkCancelButton))
    )
  }

  @ViewBuilder
  private func notificationContent(id: UUID) -> some View {
    if case let .notification(notification) = viewModel.destination, notification.id == id {
      resolvedNotificationContent(notification)
    }
  }

  @ViewBuilder
  private func resolvedNotificationContent(_ notification: AppViewModel.Notification) -> some View {
    if let content = notification.content {
      switch content {
      case let .profile(id, accessHash):
        ProfileView(mode: .otherProfile(.init(id: id, accessHash: accessHash)))
      case let .discussion(discussion):
        CommunityDiscussionView(
          details: discussion.details,
          highlightedReplyID: discussion.replyID,
          onUnauthorized: viewModel.routeToSignUp
        )
      }
    } else if notification.failed {
      notificationError(id: notification.id)
    } else {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func notificationError(id: UUID) -> some View {
    ContentUnavailableView {
      Label(.notificationOpenTitle, systemImage: Constants.error)
    } description: {
      Text(.notificationOpenError)
    } actions: {
      Button(.notificationOpenRetry) { Task { await viewModel.loadNotification(id: id) } }
    }
  }
}

private enum Constants {
  static let error = "wifi.exclamationmark"
}
