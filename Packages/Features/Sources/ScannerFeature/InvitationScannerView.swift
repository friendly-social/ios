import PhotosUI
import SwiftUI
import UIKit

public struct InvitationScannerView: View {
  @Environment(\.openURL) private var openURL
  @State private var camera: QRScannerViewModel
  @State private var model: InvitationScannerInputViewModel
  @State private var photo: PhotosPickerItem?

  public init(onSuccess: @escaping () -> Void) {
    let model = InvitationScannerInputViewModel(onSuccess: onSuccess)
    _model = State(initialValue: model)
    _camera = State(initialValue: .init(
      acceptsInput: { [weak model] in model?.acceptsInput == true },
      onCode: { [weak model] code in model?.handleScanned(code: code) }
    ))
  }

  public var body: some View {
    scannerContent()
      .safeAreaInset(edge: .bottom, spacing: .zero) { inputFooter() }
      .navigationTitle(.scannerQrcodeNavigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .background(Color(uiColor: .systemGroupedBackground))
      .task { await camera.prepare() }
      .onDisappear {
        camera.stop()
        photo = nil
      }
      .task(id: photo) { [selection = photo] in
        await handlePhoto(selection)
      }
      .alert(.scanEnterErrorAlertTitle, isPresented: $model.isErrorAlertPresented) {
        Button(.scanEnterErrorAlertButtonCancel) {
          Task { await camera.prepare() }
        }
      } message: {
        Text(model.errorMessage ?? .errorBaseMessage)
      }
  }
}

private extension InvitationScannerView {
  private func scannerContent() -> some View {
    ScrollView {
      VStack(spacing: Constants.spacing) {
        cameraPanel()
          .overlay { processingIndicator() }
        Text(.scannerQrcodeSubtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: Constants.contentWidth)
      .frame(maxWidth: .infinity)
      .padding()
    }
  }

  @ViewBuilder
  private func cameraPanel() -> some View {
    switch camera.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: Constants.placeholderHeight)
    case .running:
      if let session = camera.session {
        CameraView(session: session)
          .aspectRatio(Constants.cameraAspectRatio, contentMode: .fit)
          .clipShape(.rect(cornerRadius: Constants.cameraCornerRadius))
          .overlay { reticle() }
          .overlay(alignment: .bottomTrailing) { torchButton() }
      }
    case .noPermission:
      cameraPermissionView()
    case .ioError:
      Button(.errorBaseSubtitle) {
        Task { await camera.prepare() }
      }
      .buttonStyle(.glass)
    }
  }

  @ViewBuilder
  private func processingIndicator() -> some View {
    if model.state == .loading, camera.state != .idle, camera.state != .loading {
      ProgressView()
        .padding(Constants.processingInset)
        .glassEffect(in: .capsule)
    }
  }

  private func reticle() -> some View {
    ScannerReticle()
      .stroke(.white, style: .init(lineWidth: Constants.reticleStroke, lineCap: .round))
      .aspectRatio(Constants.reticleAspectRatio, contentMode: .fit)
      .containerRelativeFrame(.horizontal) { length, _ in
        min(length * Constants.reticleFraction, Constants.reticleWidth)
      }
      .shadow(radius: Constants.reticleShadowRadius)
      .accessibilityHidden(true)
      .allowsHitTesting(false)
  }

  @ViewBuilder
  private func torchButton() -> some View {
    if camera.hasTorch {
      Button {
        Task { await camera.toggleTorch() }
      } label: {
        Label(
          .scannerQrcodeFlashlight,
          systemImage: camera.isTorchOn ? Constants.torchOn : Constants.torchOff
        )
        .labelStyle(.iconOnly)
      }
      .buttonStyle(.glass)
      .buttonBorderShape(.circle)
      .controlSize(.large)
      .padding()
    }
  }

  private func cameraPermissionView() -> some View {
    VStack(spacing: Constants.spacing) {
      Text(.scannerQrcodeCameraPermissionTitle)
        .font(.headline)
      Text(.scannerQrcodeCameraPermissionMessage)
        .foregroundStyle(.secondary)
      Button(.openSettings) {
        if let url = camera.settingsURL {
          openURL(url)
        }
      }
      .buttonStyle(.glass)
    }
  }

  private func inputFooter() -> some View {
    photoButton()
      .frame(maxWidth: Constants.contentWidth)
      .frame(maxWidth: .infinity)
      .padding(.horizontal)
      .padding(.vertical, Constants.footerInset)
      .background(Color(uiColor: .systemGroupedBackground), ignoresSafeAreaEdges: .bottom)
      .disabled(!model.acceptsInput)
      .controlSize(.large)
  }

  private func photoButton() -> some View {
    PhotosPicker(selection: $photo, matching: .images) {
      Label(.scannerQrcodeChoosePhoto, systemImage: Constants.photoIcon)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.glass)
    .frame(maxWidth: .infinity)
  }

  private func handlePhoto(_ selected: PhotosPickerItem?) async {
    guard let selected, !Task.isCancelled else { return }
    defer {
      if !Task.isCancelled, photo == selected {
        photo = nil
      }
    }
    await model.handlePickedPhoto(selected)
  }
}

private struct ScannerReticle: Shape {
  func path(in rect: CGRect) -> Path {
    let length = min(rect.width, rect.height) * Constants.reticleArmFraction
    let radius = length * Constants.reticleRadiusFraction
    var corner = Path()
    corner.move(to: .init(x: 0, y: length))
    corner.addLine(to: .init(x: 0, y: radius))
    corner.addQuadCurve(to: .init(x: radius, y: 0), control: .zero)
    corner.addLine(to: .init(x: length, y: 0))
    var path = Path()
    for xDirection in [CGFloat(1), -1] {
      for yDirection in [CGFloat(1), -1] {
        path.addPath(corner, transform: .init(
          a: xDirection, b: 0, c: 0, d: yDirection,
          tx: xDirection > 0 ? rect.minX : rect.maxX,
          ty: yDirection > 0 ? rect.minY : rect.maxY
        ))
      }
    }
    return path
  }
}

private enum Constants {
  static let spacing: CGFloat = 16
  static let contentWidth: CGFloat = 440
  static let placeholderHeight: CGFloat = 280
  static let cameraAspectRatio: CGFloat = 0.9
  static let cameraCornerRadius: CGFloat = 24
  static let reticleAspectRatio: CGFloat = 1
  static let reticleFraction: CGFloat = 0.58
  static let reticleWidth: CGFloat = 208
  static let reticleShadowRadius: CGFloat = 3
  static let reticleStroke: CGFloat = 3
  static let reticleArmFraction: CGFloat = 0.24
  static let reticleRadiusFraction: CGFloat = 0.45
  static let footerInset: CGFloat = 8
  static let processingInset: CGFloat = 14
  static let torchOn = "flashlight.on.fill"
  static let torchOff = "flashlight.off.fill"
  static let photoIcon = "photo"
}
