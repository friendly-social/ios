import SwiftUI

struct FeedView: View {
    private let viewModel: FeedViewModel = FeedViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack {
                switch viewModel.state {
                case .loading: LoadingView()
                case .ioError: IOErrorView()
                case .success: FeedSuccessView()
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear { viewModel.appear() }
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
    var body: some View {

    }
}
