import ActivityDiscussionFeature
import ActivityFeature
import SwiftUI

public struct ActivityRootView: View {
  @State private var model: ActivityViewModel
  private let onUnauthorized: () -> Void

  public init(onUnauthorized: @escaping () -> Void) {
    self.onUnauthorized = onUnauthorized
    _model = State(initialValue: ActivityViewModel(onUnauthorized: onUnauthorized))
  }

  public var body: some View { contentView() }
}

private extension ActivityRootView {
  private func contentView() -> some View {
    ActivityView(model: model)
      .navigationDestination(item: $model.discussion) { destination in
        ActivityDiscussionView(
          event: destination.event, session: destination.session,
          onUnauthorized: onUnauthorized,
          onRead: { model.didRead(destination.event.id, session: destination.session) })
          .toolbar(.hidden, for: .tabBar)
      }
  }
}
