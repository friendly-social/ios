//
//  QRScannerCameraView.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import SwiftUI

struct QRScannerCameraView: View {
  @Environment(\.openURL) private var openURL
  @State private var viewModel: QRScannerViewModel
  @State private var isScanningAnimation = false

  init(onDismiss: @escaping (String?) -> Void) {
    _viewModel = State(wrappedValue: QRScannerViewModel(onDismiss: onDismiss))
  }

  var body: some View {
    NavigationView {
      scannerContent()
        .toolbar { toolbarContent() }
        .onDisappear { viewModel.stop() }
        .task { await viewModel.prepare() }
    }
  }
}

private extension QRScannerCameraView {
  @ViewBuilder
  private func scannerContent() -> some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
    case .running:
      scanView()
    case .noPermission:
      permissionView()
    case .ioError:
      errorView()
    }
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .principal) {
      Text(.scannerQrcodeNavigationTitle)
    }
    ToolbarItem(placement: .primaryAction) {
      Button(action: { viewModel.onDismiss(code: nil) }) {
        Image(systemName: Constants.closeIcon)
      }
    }
  }

  private func scanView() -> some View {
    VStack(spacing: Constants.spacing) {
      Text(.scannerQrcodeTitle)
        .font(.title2)
        .padding(.top, Constants.titleTopInset)

      Text(.scannerQrcodeSubtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer(minLength: .zero)

      GeometryReader { proxy in
        cameraPreview(width: proxy.size.width)
      }
      .padding(.horizontal, Constants.previewHorizontalInset)

      Spacer(minLength: Constants.contentInset)
    }
    .padding(Constants.contentInset)
  }

  private func cameraPreview(width: CGFloat) -> some View {
    ZStack {
      if let session = viewModel.session {
        CameraView(session: session)
          .scaleEffect(Constants.cameraScale)
      }
      reticle()
    }
    .frame(width: width, height: width)
    .overlay(alignment: .top) { scanLine(width: width) }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear { startScannerAnimation() }
  }

  private func reticle() -> some View {
    ForEach(Constants.reticleIndices, id: \.self) { index in
      RoundedRectangle(cornerRadius: Constants.reticleCornerRadius, style: .circular)
        .trim(from: Constants.reticleTrimStart, to: Constants.reticleTrimEnd)
        .stroke(
          Constants.scanColor,
          style: StrokeStyle(lineWidth: Constants.reticleStrokeWidth, lineCap: .round, lineJoin: .round)
        )
        .rotationEffect(.degrees(Double(index) * Constants.reticleRotationStep))
    }
  }

  private func scanLine(width: CGFloat) -> some View {
    Rectangle()
      .fill(Constants.scanColor)
      .frame(height: Constants.scanLineHeight)
      .shadow(
        color: .black.opacity(Constants.scanLineShadowOpacity),
        radius: Constants.scanLineShadowRadius,
        y: isScanningAnimation ? Constants.scanLineShadowOffset : -Constants.scanLineShadowOffset
      )
      .offset(y: isScanningAnimation ? width : .zero)
  }

  private func startScannerAnimation() {
    guard !isScanningAnimation else { return }
    let animation = Animation.easeInOut(duration: Constants.animationDuration)
      .delay(Constants.animationDelay)
      .repeatForever(autoreverses: true)
    withAnimation(animation) {
      isScanningAnimation = true
    }
  }

  private func permissionView() -> some View {
    VStack(spacing: Constants.messageSpacing) {
      Text(.scannerQrcodeCameraPermissionTitle)
        .font(.title2)

      Text(.scannerQrcodeCameraPermissionMessage)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button(.openSettings) {
        guard let url = viewModel.settingsURL else { return }
        openURL(url)
      }
      .buttonStyle(.borderedProminent)

      Button(.buttonBaseClose, role: .cancel) { viewModel.onDismiss(code: nil) }
        .buttonStyle(.glass)
        .padding(.horizontal)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorView() -> some View {
    VStack(spacing: Constants.messageSpacing) {
      Text(.errorBaseTitle)
        .font(.title2)

      retryButton()

      Button {
        viewModel.onDismiss(code: nil)
      } label: {
        errorButtonLabel(.buttonBaseClose)
      }
      .buttonStyle(.glass)
      .padding(.horizontal)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func retryButton() -> some View {
    Button {
      Task { await viewModel.prepare() }
    } label: {
      errorButtonLabel(.errorBaseSubtitle)
    }
    .buttonStyle(.glassProminent)
    .padding(.horizontal)
  }

  private func errorButtonLabel(_ title: LocalizedStringResource) -> some View {
    Text(title)
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding()
  }
}

private enum Constants {
  static let spacing: CGFloat = 8
  static let messageSpacing: CGFloat = 12
  static let contentInset: CGFloat = 15
  static let titleTopInset: CGFloat = 20
  static let previewHorizontalInset: CGFloat = 45
  static let cameraScale: CGFloat = 0.97
  static let reticleIndices = 0...4
  static let reticleCornerRadius: CGFloat = 2
  static let reticleTrimStart: CGFloat = 0.61
  static let reticleTrimEnd: CGFloat = 0.64
  static let reticleStrokeWidth: CGFloat = 5
  static let reticleRotationStep = 90.0
  static let scanColor = Color.blue
  static let scanLineHeight: CGFloat = 2.5
  static let scanLineShadowOpacity = 0.8
  static let scanLineShadowRadius: CGFloat = 8
  static let scanLineShadowOffset: CGFloat = 15
  static let animationDuration = 0.85
  static let animationDelay = 0.1
  static let closeIcon = "xmark"
}
