import ActivityService
import SwiftUI

public struct ActivityView: View {
  @Bindable private var model: ActivityViewModel

  public init(model: ActivityViewModel) { self.model = model }

  public var body: some View {
    contentView()
      .navigationTitle(.activityTitle)
      .navigationBarTitleDisplayMode(.inline)
      .task { await model.start() }
      .refreshable { await model.load() }
  }
}

private extension ActivityView {
  @ViewBuilder
  private func contentView() -> some View {
    if model.events.isEmpty {
      emptyContent()
    } else {
      listView()
    }
  }

  @ViewBuilder
  private func emptyContent() -> some View {
    if model.isLoading {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let error = model.error {
      ContentUnavailableView {
        Label(error, systemImage: Constants.error)
      } actions: {
        Button(.activityRetry) { Task { await model.load() } }
      }
    } else {
      ContentUnavailableView(.activityEmpty, systemImage: Constants.empty,
                            description: Text(.activityEmptyDescription))
    }
  }

  private func listView() -> some View {
    List {
      ForEach(ActivityTimeGroup.allCases) { group in
        let events = model.events(in: group)
        if !events.isEmpty {
          Section {
            ForEach(events) { event in rowView(event) }
          } header: { groupTitle(group) }
        }
      }
      if let error = model.error { Text(error).foregroundStyle(.secondary) }
      paginationView()
    }
    .listStyle(.insetGrouped)
  }

  private func rowView(_ event: ActivityEvent) -> some View {
    Button { model.openButtonTapped(event) } label: {
      ActivityRowView(event: event, avatarURL: model.avatarURL(for: event))
        .foregroundStyle(Constants.foreground)
    }
    .listRowBackground(event.isRead ? Constants.rowBackground : Constants.unreadBackground)
  }

  @ViewBuilder
  private func paginationView() -> some View {
    if model.isLoadingMore {
      ProgressView().frame(maxWidth: .infinity)
    } else if let error = model.pageError {
      VStack {
        Text(error).foregroundStyle(.secondary)
        Button(.activityRetry) { Task { await model.loadMore() } }
      }
    } else if model.nextID != nil {
      Button(.activityLoadMore) { Task { await model.loadMore() } }
        .task { await model.loadMore() }
    }
  }

  private func groupTitle(_ group: ActivityTimeGroup) -> Text {
    switch group {
    case .today: Text(.activityToday)
    case .yesterday: Text(.activityYesterday)
    case .older: Text(.activityOlder)
    }
  }
}

private enum Constants {
  static let empty = "bell"
  static let error = "wifi.exclamationmark"
  static let foreground = Color.primary
  static let rowBackground = Color(uiColor: .secondarySystemGroupedBackground)
  static let unreadBackground = Color.accentColor.opacity(0.08)
}
