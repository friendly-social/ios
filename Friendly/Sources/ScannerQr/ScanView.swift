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
    private let onEmailLogin: (() -> Void)?
    
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    init(
        isBlocked: Bool,
        onEmailLogin: (() -> Void)? = nil,
        onSuccess: @escaping () -> Void
    ) {
        self.isBlocked = isBlocked
        self.onEmailLogin = onEmailLogin
        _viewModel = StateObject(wrappedValue: ScanToUseAppViewModel(onSuccess: onSuccess))
    }

    var body: some View {
        NavigationView {
            ZStack {
                stateView
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isBlocked {
                    toolbarContent
                }
            }
            .alert(
                String(localized: .scanEnterErrorAlertTitle),
                isPresented: $viewModel.isErrorAlertPresented
            ) {
                Button(
                    String(localized: .scanEnterErrorAlertButtonCancel),
                    role: .cancel
                ) {
                    viewModel.tapCancelButton()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(
                        String(
                            localized: LocalizedStringResource(
                                stringLiteral: errorMessage
                            )
                        )
                    )
                } else {
                    Text(.errorBaseMessage)
                }
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

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .idle:
            contentView
        case .loading:
            LoadingView()
        }
    }

    private var contentView: some View {
        VStack(spacing: 20) {
            Spacer()
            qrCodeImage
            titleLabel
            subtitleLabel
            emailLoginSectionView
            Spacer()
            openScannerButton
            photoPickerButton
            Spacer(minLength: 24)
        }
    }

    private var qrCodeImage: some View {
        Image(systemName: "qrcode.viewfinder")
            .font(.system(size: 56))
            .padding(.bottom, 8)
    }

    private var titleLabel: some View {
        Text(.scanEnterInfoTitle)
            .font(.title3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    private var subtitleLabel: some View {
        Text(.scanEnterInfoSubtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var emailLoginSectionView: some View {
        if isBlocked, let onEmailLogin {
            Text(.scanEnterBlockedEmailDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            NavigationLink {
                EmailLoginView(onSuccess: onEmailLogin)
            } label: {
                Text(.scanEnterBlockedEmailLoginButton)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
    }

    private var openScannerButton: some View {
        Button {
            viewModel.openScanner()
        } label: {
            Text(.scanEnterOpenScanner)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.glassProminent)
        .padding(.horizontal)
    }

    private var photoPickerButton: some View {
        PhotosPicker(
            selection: $pickedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Text(.scanEnterOpenPhotoScanner)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.glass)
        .padding(.horizontal)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(.scannerQrcodeNavigationTitle)
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
