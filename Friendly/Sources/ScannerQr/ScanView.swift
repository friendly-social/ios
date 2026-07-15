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
    @FocusState private var isLinkTextFieldFocused: Bool
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
        NavigationStack {
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
                viewModel.alert?.title ?? "",
                isPresented: Binding(
                    get: { viewModel.alert != nil },
                    set: { if !$0 { viewModel.alert = nil } },
                ),
                actions: { 
                    Button(
                        String(localized: .scanEnterErrorAlertButtonOkay),
                        role: .cancel,
                    ) {
                        viewModel.resetState()
                    }
                },
                message: {
                    if let message = viewModel.alert?.message {
                        Text(message)
                    }
                },
            )
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
                        viewModel.alert = .photoInvalidImage(
                            title: .scanEnterErrorAlertTitleDefault,
                        )
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
        ScrollView { 
            VStack(spacing: 20) {
                qrCodeImage
                    .padding(.bottom, 8)

                titleLabel
                subtitleLabel

                Spacer(minLength: 40)

                inviteLinkTextField
                emailLoginSectionView
                openScannerButton
                photoPickerButton

                Spacer(minLength: 24)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .onTapGesture { isLinkTextFieldFocused = false }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .padding(.top)
    }

    private var qrCodeImage: some View {
        Image(systemName: "qrcode.viewfinder")
            .font(.system(size: 56))
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

    private var inviteLinkTextField: some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(.secondary)

            TextField(
                .inviteLink,
                text: $viewModel.inviteLinkText,
            )
            .focused($isLinkTextFieldFocused)
            .font(.body)
            .frame(maxWidth: .infinity)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .autocapitalization(.none)
            .onSubmit { viewModel.handleEnteredInviteLinkText() }
            .overlay(alignment: .trailing) {
                if viewModel.inviteLinkText.isEmpty {
                    Button(.paste) {
                        guard let text = UIPasteboard.general.string else {
                            return
                        }
                        viewModel.inviteLinkText = text
                        viewModel.handleEnteredInviteLinkText()
                    }
                    .padding(.trailing, 8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .padding(.horizontal)
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
