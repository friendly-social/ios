import ActivityDiscussionFeature
import ActivityFeature
import FriendlyUIKit
import ProfileFeature
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
      .navigationDestination(item: discussionDestination) { destination in
        discussionView(destination).toolbar(.hidden, for: .tabBar)
      }
      .sheet(item: profileDestination) { destination in
        profileView(destination)
      }
  }

  private var discussionDestination: Binding<ActivityViewModel.Destination.Discussion?> {
    Binding(
      get: { model.destination?.discussion },
      set: { destination in
        if let destination { model.destination = .discussion(destination) }
        else if model.destination?.discussion != nil { model.destination = nil }
      })
  }

  private var profileDestination: Binding<ActivityViewModel.Destination.Profile?> {
    Binding(
      get: { model.destination?.profile },
      set: { destination in
        if let destination { model.destination = .profile(destination) }
        else if model.destination?.profile != nil { model.destination = nil }
      })
  }

  private func discussionView(_ destination: ActivityViewModel.Destination.Discussion) -> some View {
    ActivityDiscussionView(
      event: destination.event, session: destination.session,
      onUnauthorized: onUnauthorized,
      onRead: { model.didRead(destination.event.id, session: destination.session) })
  }

  private func profileView(_ destination: ActivityViewModel.Destination.Profile) -> some View {
    RouterView { router in
      ProfileView(router: router, mode: .otherProfile(.init(
        id: destination.userID, accessHash: destination.accessHash)))
    }
    .presentationDragIndicator(.visible)
    .task { await model.profileOpened(destination) }
  }
}
