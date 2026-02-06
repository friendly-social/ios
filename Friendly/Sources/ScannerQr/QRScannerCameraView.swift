//
//  QRScannerView.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import SwiftUI
import AVFoundation

struct QRScannerCameraView: View {
    @Environment(\.openURL) private var openURL

    @StateObject private var qrDelegate = QrScannerDelegate()
    @StateObject private var viewModel: QRScannerViewModel

    @State private var isScanningAnimation = false

    init(onDismiss: @escaping (String?) -> Void) {
        let delegate = QrScannerDelegate()
        _qrDelegate = StateObject(wrappedValue: delegate)
        _viewModel = StateObject(wrappedValue: QRScannerViewModel(
            qrDelegate: delegate,
            onDismiss: onDismiss
        ))
    }

    var body: some View {
        NavigationView {
            ZStack {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .onAppear { viewModel.prepare() }

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
                    Text("scanner_qrcode_navigation_title")
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
            .onChange(of: qrDelegate.scanndeCode) { _, newValue in
                guard let code = newValue else { return }
                viewModel.didScan(code: code)
                stopScannerAnimation()
            }
        }
    }

    // MARK: - Views

    private func scanView() -> some View {
        VStack(spacing: 8) {
            Text("scanner_qrcode_title")
                .font(.title2)
                .padding(.top, 20)

            Text("scanner_qrcode_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: .zero)

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    CameraView(
                        frameSize: CGSize(width: size.width, height: size.width),
                        session: viewModel.sessionBinding // см. ниже
                    )
                    .scaleEffect(0.97)

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
            Text("scanner_qrcode_camera_permission_title")
                .font(.title2)

            Text("scanner_qrcode_camera_permission_message")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("open_settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .buttonStyle(.borderedProminent)

            Button("", role: .cancel) { viewModel.onDismiss(code: nil) }
                .buttonStyle(.glass)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView() -> some View {
        VStack(spacing: 12) {
            Text("error_base_title")
                .font(.title2)

            Button {
                viewModel.prepare()
            } label: {
                Text("error_base_subtite")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
            
            Button {
                viewModel.onDismiss(code: nil)
            } label: {
                Text("button_base_close")
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

    private func stopScannerAnimation() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isScanningAnimation = false
        }
    }
}
