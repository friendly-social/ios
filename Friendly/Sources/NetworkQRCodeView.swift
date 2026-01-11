import SwiftUI
import QRCode

struct NetworkQRCodeView : View {
    private let viewModel: NetworkQRCodeViewModel

    init(onDismiss: @escaping () -> Void) {
        self.viewModel = NetworkQRCodeViewModel(onDismiss: onDismiss)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationView {
            ZStack {
                switch viewModel.state {
                case .loading: LoadingView()
                case .ioError: IOErrorView()
                case .success(let success):
                    NetworkQRCodeSuccessView(
                        viewModel: viewModel,
                        url: success.url,
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("network_qrcode_title")
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

private struct NetworkQRCodeSuccessView: View {
    let viewModel: NetworkQRCodeViewModel
    let url: URL

    var body: some View {
        VStack {
            QRCodeRender(url: url)
            Text("network_qrcode_description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: viewModel.onDismiss) {
                Text("network_qrcode_ok")
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
    private let qrCode: UIImage?

    init(url: URL) {
        let image = try? QRCode.build
            .text(url.absoluteString)
            .quietZonePixelCount(3)
            .background.cornerRadius(3)
            .eye.shape(QRCode.EyeShape.RoundedOuter())
            .generate.image(dimension: 600)
        if let image = image {
            qrCode = UIImage(cgImage: image)
        } else {
            qrCode = nil
        }
    }

    var body: some View {
        if let qrCode = qrCode {
            Image(uiImage: qrCode)
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
                Text("network_qrcode_link")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.subheadline)
            .padding()
        }
        .buttonStyle(.borderless)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(url: url)
               .presentationDetents([.medium])
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
