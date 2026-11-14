import ActivityService
import FriendlyUIKit
import SwiftUI

public struct ActivityView: View {
  @Bindable private var model: ActivityViewModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var availableHeight: CGFloat = 0
  @State private var notificationBannerHeight: CGFloat = 0

  public init(model: ActivityViewModel) { self.model = model }

  public var body: some View {
    listView(availableHeight: availableHeight)
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
        availableHeight = $0
      }
      .background(Constants.background)
      .navigationTitle(.activityTitle)
      .navigationBarTitleDisplayMode(.inline)
      .task { await model.start() }
      .task(id: scenePhase == .active) {
        if scenePhase == .active { await model.refreshNotificationAuthorization() }
      }
      .refreshable {
        await model.refreshNotificationAuthorization()
        await model.load()
      }
  }
}

private extension ActivityView {
  @ViewBuilder
  private func notificationBanner() -> some View {
    if model.showsNotificationBanner {
      ActionCard(
        title: model.notificationBannerTitle,
        message: model.notificationBannerMessage,
        systemImage: Constants.empty,
        backgroundColor: Color(.informationCardBackground),
        foregroundColor: Color(.informationCardForeground)
      ) {
        Task { await model.notificationBannerTapped() }
      }
      .disabled(model.isUpdatingNotifications)
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
        notificationBannerHeight = $0
      }
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
      ContentUnavailableView(
        .activityEmpty,
        systemImage: Constants.empty,
        description: Text(.activityEmptyDescription)
      )
    }
  }

  private func listView(availableHeight: CGFloat) -> some View {
    List {
      if model.showsNotificationBanner {
        Section {
          notificationBanner()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
      }
      if model.events.isEmpty { emptyRow(availableHeight: availableHeight) }
      else { activitySections() }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Constants.background)
  }

  private func emptyRow(availableHeight: CGFloat) -> some View {
    let bannerHeight = model.showsNotificationBanner ? notificationBannerHeight : Constants.zero
    let contentHeight = availableHeight - bannerHeight - Constants.emptyReservedSpace
    return emptyContent()
      .frame(maxWidth: .infinity)
      .frame(minHeight: max(Constants.zero, contentHeight))
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }

  @ViewBuilder
  private func activitySections() -> some View {
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
  static let zero: CGFloat = 0
  static let emptyReservedSpace: CGFloat = 80
  static let background = Color(uiColor: .systemGroupedBackground)
}
