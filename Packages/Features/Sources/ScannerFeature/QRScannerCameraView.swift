//
//  QRScannerView.swift
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
            ZStack {
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(.scannerQrcodeNavigationTitle)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.onDismiss(code: nil) }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onDisappear {
                viewModel.stop()
            }
            .task { await viewModel.prepare() }
        }
    }

    // MARK: - Views

    private func scanView() -> some View {
        VStack(spacing: 8) {
            Text(.scannerQrcodeTitle)
                .font(.title2)
                .padding(.top, 20)

            Text(.scannerQrcodeSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: .zero)

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    if let session = viewModel.session {
                        CameraView(
                            frameSize: CGSize(width: size.width, height: size.width),
                            session: session
                        )
                        .scaleEffect(0.97)
                    }

                    ForEach(0...4, id: \.self) { index in
                        let rotation = Double(index) * 90.0
                        RoundedRectangle(cornerRadius: 2, style: .circular)
                            .trim(from: 0.61, to: 0.64)
                            .stroke(
                                Color.blue,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                            )
                            .rotationEffect(.degrees(rotation))
                    }
                }
                .frame(width: size.width, height: size.width)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 2.5)
                        .shadow(
                            color: .black.opacity(0.8),
                            radius: 8,
                            x: 0,
                            y: isScanningAnimation ? 15 : -15
                        )
                        .offset(y: isScanningAnimation ? size.width : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { startScannerAnimation() }
            }
            .padding(.horizontal, 45)

            Spacer(minLength: 15)
        }
        .padding(15)
    }

    private func permissionView() -> some View {
        VStack(spacing: 12) {
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
        VStack(spacing: 12) {
            Text(.errorBaseTitle)
                .font(.title2)

            Button {
                Task { await viewModel.prepare() }
            } label: {
                Text(.errorBaseSubtitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
            
            Button {
                viewModel.onDismiss(code: nil)
            } label: {
                Text(.buttonBaseClose)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glass)
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Animation

    private func startScannerAnimation() {
        guard !isScanningAnimation else { return }
        withAnimation(.easeInOut(duration: 0.85).delay(0.1).repeatForever(autoreverses: true)) {
            isScanningAnimation = true
        }
    }

}
