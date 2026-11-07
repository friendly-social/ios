import FriendlyUIKit
import ProfileFeature
import SwiftUI

public struct FeedView: View {
    @State private var viewModel: FeedViewModel

    public init(router: Router) {
        viewModel = FeedViewModel(router: router)
    }

    public var body: some View {
        ZStack {
            switch viewModel.state {
            case .loading: LoadingView()
            case .ioError: IOErrorView()
            case let .success(entries): FeedSuccessView(entries: entries)
            }
        }
        .animation(
            .easeInOut(duration: Constants.animationDuration),
            value: viewModel.state.rawValue,
        )
        .frame(maxHeight: .infinity)
        .background(Constants.background)
        .onAppear { viewModel.appear() }
        .navigationDestination(
            for: FeedViewModel.ProfileDestination.self,
        ) { destination in
            let profile = ProfileView.OtherProfile(
                id: destination.id,
                accessHash: destination.accessHash,
            )
            ProfileView(
                mode: .otherProfile(profile),
            )
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
            Image(systemName: Constants.connectionErrorSymbol)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.stateIconSize, height: Constants.stateIconSize)
                .foregroundStyle(.secondary)
            Text(.ioErrorTitle)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            Text(.ioErrorSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FeedSuccessView: View {
    let entries: [FeedViewModel.Entry]

    var body: some View {
        ZStack {
            FeedEmptyView()
            let entries = Array(entries.prefix(Constants.visibleCardCount).enumerated())
            ForEach(entries, id: \.element.id) { (index, entry) in
                FeedSwipeCardView(entry: entry)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .zIndex(Double(Constants.visibleCardCount - index - 1))
            }
        }
    }
}

private struct FeedEmptyView: View {
    var body: some View {
        VStack {
            Image(systemName: Constants.emptySymbol)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.stateIconSize, height: Constants.stateIconSize)
                .foregroundStyle(.secondary)
            Text(.feedEmpty)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            Text(.feedEmptyAdvice)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum Constants {
  static let background = Color(uiColor: .systemGroupedBackground)
  static let animationDuration = 0.3
  static let stateIconSize: CGFloat = 50
  static let visibleCardCount = 2
  static let connectionErrorSymbol = "wifi.slash"
  static let emptySymbol = "tray"
}
