import SwiftUI

public struct NetworkQRCodeView: View {
    @State private var viewModel: NetworkQRCodeViewModel

    public init(onDismiss: @escaping () -> Void) {
        self.viewModel = NetworkQRCodeViewModel(onDismiss: onDismiss)
    }

    public var body: some View {
        NavigationView {
            ZStack {
                switch viewModel.state {
                case .loading: LoadingView()
                case .ioError: IOErrorView()
                case let .success(success):
                    NetworkQRCodeSuccessView(
                        viewModel: viewModel,
                        url: success.url,
                        image: success.image,
                    )
                }
            }
            .animation(
                .easeInOut(duration: 0.3),
                value: viewModel.state.rawValue,
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(.networkQrcodeTitle)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: viewModel.onDismiss) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear { viewModel.appear() }
            .background(Color(uiColor: .systemGroupedBackground))
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

private struct NetworkQRCodeSuccessView: View {
    let viewModel: NetworkQRCodeViewModel
    let url: URL
    let image: UIImage?

    var body: some View {
        VStack {
            QRCodeRender(image: image)
            Text(.networkQrcodeDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: viewModel.onDismiss) {
                Text(.networkQrcodeOk)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
            QRCodeLink(url: url)
        }
    }
}

private struct QRCodeRender: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(1/1, contentMode: .fit)
                .padding(.horizontal)
        }
    }
}

private struct QRCodeLink: View {
    let url: URL

    @State private var showShareSheet = false

    var body: some View {
        Button(action: { showShareSheet = true }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text(.networkQrcodeLink)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.subheadline)
            .padding()
        }
        .buttonStyle(.borderless)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(url: url)
               .presentationDetents([.medium, .large])
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    typealias UIViewControllerType = UIActivityViewController

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let viewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil,
        )
        return viewController
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController, context: Context,
    ) {}
}
