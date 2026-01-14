import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()

    var body: some View {
        VStack {
            switch viewModel.state {
            case .loading: LoadingView()
            case .ioError: IOErrorView()
            case .success(let entries): FeedSuccessView(entries: entries)
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: viewModel.state.rawValue,
        )
        .frame(maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear { viewModel.appear() }
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
            Image(systemName: "wifi.slash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .foregroundStyle(.secondary)
            Text("io_error_title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            Text("io_error_subtitle")
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
            let entries = Array(entries.prefix(2).enumerated())
            ForEach(entries, id: \.element.id) { (index, entry) in
                FeedSwipeCardView(
                    avatarUrl: entry.avatarUrl,
                    nickname: entry.nickname,
                    description: entry.description,
                    interests: entry.interests,
                    onLike: entry.onLike,
                    onDislike: entry.onDislike,
                )
                .padding(.horizontal)
                .padding(.bottom)
                .zIndex(1 - Double(index))
            }
        }
    }
}

private struct FeedEmptyView: View {
    var body: some View {
        VStack {
            Image(systemName: "tray")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .foregroundStyle(.secondary)
            Text("feed_empty")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            Text("feed_empty_advice")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

