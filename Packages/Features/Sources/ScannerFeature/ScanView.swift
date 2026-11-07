//
//  ScanView.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import AuthFeature
import SwiftUI

public struct ScanToUseAppView: View {
  @State private var viewModel: ScanToUseAppViewModel

  public init(
    onEmailLogin: @escaping () -> Void,
    onSignOut: @escaping () -> Void,
    onSuccess: @escaping () -> Void
  ) {
    _viewModel = State(initialValue: .init(
      onEmailLogin: onEmailLogin, onSignOut: onSignOut, onSuccess: onSuccess
    ))
  }

  public var body: some View {
    NavigationStack {
      contentView
        .safeAreaInset(edge: .bottom, spacing: 0) { actionFooter }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { signOutToolbar() }
        .navigationDestination(item: $viewModel.emailDestination) { _ in
          EmailLoginView(onSuccess: viewModel.onEmailLogin)
        }
        .sheet(item: $viewModel.scannerDestination) { _ in scannerSheet() }
    }
  }
}

private extension ScanToUseAppView {
  private func scannerSheet() -> some View {
    NavigationStack {
      InvitationScannerView(onSuccess: viewModel.completeScan)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button(action: viewModel.closeScanner) {
              Label(.buttonBaseClose, systemImage: Constants.closeIcon)
                .labelStyle(.iconOnly)
            }
          }
        }
    }
  }

  private var contentView: some View {
    VStack(spacing: Constants.contentSpacing) {
      Spacer()
      qrCodeImage
      titleLabel
      subtitleLabel
      Spacer()
    }
  }

  private var qrCodeImage: some View {
    Image(systemName: Constants.scanIcon)
      .font(.system(size: Constants.scanIconSize))
      .padding(.bottom, Constants.scanIconBottomInset)
  }

  private var titleLabel: some View {
    Text(.scanEnterInfoTitle)
      .font(.title3)
      .multilineTextAlignment(.center)
      .padding(.horizontal, Constants.textHorizontalInset)
  }

  private var subtitleLabel: some View {
    Text(.scanEnterInfoSubtitle)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, Constants.textHorizontalInset)
  }

  private var actionFooter: some View {
    VStack(spacing: Constants.footerSpacing) {
      Text(.scanEnterBlockedEmailDescription)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      emailLoginButton
      openScannerButton
    }
    .padding(.horizontal, Constants.footerHorizontalInset)
    .padding(.bottom, Constants.footerBottomInset)
  }

  private var emailLoginButton: some View {
    Button(action: viewModel.openEmailLogin) {
      Text(.scanEnterBlockedEmailLoginButton)
        .font(.headline)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.capsule)
    .controlSize(.large)
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
  }

  private func signOutToolbar() -> some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button(.scanEnterSignOut, action: viewModel.requestSignOut)
        .confirmationDialog(
          .scanEnterSignOutConfirmation,
          isPresented: $viewModel.confirmsSignOut
        ) {
          Button(.scanEnterSignOut, role: .destructive, action: viewModel.signOut)
        }
    }
  }
}

private enum Constants {
  static let scanIcon = "qrcode.viewfinder"
  static let scanIconSize: CGFloat = 56
  static let scanIconBottomInset: CGFloat = 8
  static let textHorizontalInset: CGFloat = 16
  static let contentSpacing: CGFloat = 20
  static let closeIcon = "xmark"
  static let footerSpacing: CGFloat = 12
  static let footerHorizontalInset: CGFloat = 24
  static let footerBottomInset: CGFloat = 8
}
