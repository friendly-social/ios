//
//  ScanView.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import AuthFeature
import PhotosUI
import SwiftUI

public struct ScanToUseAppView: View {
    @State private var viewModel: ScanToUseAppViewModel
    @State private var pickedPhotoItem: PhotosPickerItem? = nil
    @State private var showsSignOutConfirmation = false
    private var isBlocked: Bool
    private let onEmailLogin: (() -> Void)?
    private let onSignOut: (() -> Void)?
    
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    public init(
        isBlocked: Bool,
        onEmailLogin: (() -> Void)? = nil,
        onSignOut: (() -> Void)? = nil,
        onSuccess: @escaping () -> Void
    ) {
        self.isBlocked = isBlocked
        self.onEmailLogin = onEmailLogin
        self.onSignOut = onSignOut
        _viewModel = State(wrappedValue: ScanToUseAppViewModel(onSuccess: onSuccess))
    }

    public var body: some View {
        NavigationView {
            ZStack {
                stateView
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isBlocked {
                    toolbarContent
                } else if onSignOut != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(.scanEnterSignOut) { showsSignOutConfirmation = true }
                            .confirmationDialog(
                                .scanEnterSignOutConfirmation,
                                isPresented: $showsSignOutConfirmation
                            ) {
                                if let onSignOut {
                                    Button(.scanEnterSignOut, role: .destructive, action: onSignOut)
                                }
                            }
                    }
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
                    Text(verbatim: errorMessage)
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
                    await viewModel.handlePickedPhoto(newItem)
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
                    .contentShape(.rect)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, 24)
        }
    }

    private var openScannerButton: some View {
        Button {
            viewModel.openScanner()
        } label: {
            Text(.scanEnterOpenScanner)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.horizontal, 24)
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
                .contentShape(.rect)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.horizontal, 24)
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
