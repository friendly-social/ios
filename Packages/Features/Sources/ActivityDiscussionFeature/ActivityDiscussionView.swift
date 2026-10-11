import ActivityService
import CommunityFeature
import CommunityProfileService
import SwiftUI

public struct ActivityDiscussionView: View {
  @State private var model: ActivityDiscussionViewModel
  @State private var loadAttempt = 0
  private let onUnauthorized: () -> Void

  public init(
    event: ActivityEvent, session: CommunitySession,
    onUnauthorized: @escaping () -> Void, onRead: @escaping () -> Void
  ) {
    self.onUnauthorized = onUnauthorized
    _model = State(initialValue: ActivityDiscussionViewModel(
      event: event, session: session, onUnauthorized: onUnauthorized, onRead: onRead))
  }

  public var body: some View { contentView() }
}

private extension ActivityDiscussionView {
  private func contentView() -> some View {
    discussionContent()
      .background(Constants.background)
      .navigationTitle(.activityDiscussionTitle)
      .navigationBarTitleDisplayMode(.inline)
      .task(id: loadAttempt) { await model.load() }
  }

  @ViewBuilder
  private func discussionContent() -> some View {
    if let discussion = model.discussion {
      CommunityDiscussionView(
        details: discussion.details, highlightedReplyID: discussion.replyID,
        onUnauthorized: onUnauthorized)
    } else if let error = model.error {
      ContentUnavailableView {
        Label(.activityDiscussionTitle, systemImage: Constants.error)
      } description: {
        Text(error)
      } actions: {
        Button(.activityDiscussionRetry) { loadAttempt += 1 }
      }
    } else {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

private enum Constants {
  static let background = Color(uiColor: .systemBackground)
  static let error = "wifi.exclamationmark"
}
