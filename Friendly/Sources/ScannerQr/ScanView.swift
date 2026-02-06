//
//  ScanView.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import SwiftUI
import PhotosUI

struct ScanToUseAppView: View {
    @StateObject private var viewModel: ScanToUseAppViewModel
    @State private var pickedPhotoItem: PhotosPickerItem? = nil
    private var isBlocked: Bool
    
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    init(
        isBlocked: Bool,
        onSuccess: @escaping () -> Void
    ) {
        self.isBlocked = isBlocked
        _viewModel = StateObject(wrappedValue: ScanToUseAppViewModel(onSuccess: onSuccess))
    }

    var body: some View {
        NavigationView {
            ZStack {
                switch viewModel.state {
                case .idle: content
                case .loading: LoadingView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isBlocked {
                    toolbarContent
                }
            }
            .alert(
                "scan_enter_error_alert_title",
                isPresented: $viewModel.isErrorAlertPresented
            ) {
                Button("scan_enter_error_alert_button_cancel", role: .cancel) { }
            } message: {
                Text(
                    String(
                        localized: LocalizedStringResource(
                            stringLiteral: viewModel.errorMessage ?? "error_base_message"
                        )
                    )
                )
            }
            .sheet(isPresented: $viewModel.isScannerPresented) {
                QRScannerCameraView { code in
                    guard let code, !code.isEmpty else {
                        viewModel.closeScanner()
                        return
                    }
                    viewModel.handleScanned(code: code)
                }
            }
            .onChange(of: pickedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    defer { pickedPhotoItem = nil }
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        viewModel.handlePickedImageData(data)
                    } else {
                        viewModel.errorMessage = "scan_enter_photo_invalid_image"
                        viewModel.isErrorAlertPresented = true
                    }
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 56))
                .padding(.bottom, 8)

            Text("scan_enter_info_title")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                

            Text("scan_enter_info_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer()

            Button {
                viewModel.openScanner()
            } label: {
                Text("scan_enter_open_scanner")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.glassProminent)
            .padding(.horizontal)

            PhotosPicker(
                selection: $pickedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("scan_enter_open_photo_scanner")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glass)
            .padding(.horizontal)

            Spacer(minLength: 24)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("scanner_qrcode_navigation_title")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
            }
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
