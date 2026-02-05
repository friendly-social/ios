//
//  ScanView.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import SwiftUI

struct ScanToUseAppView: View {
    @StateObject private var viewModel: ScanToUseAppViewModel

    init(onSuccess: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: ScanToUseAppViewModel(onSuccess: onSuccess))
    }

    var body: some View {
        NavigationView {
            ZStack {
                content

                if viewModel.state == .loading {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "scan_enter_error_alert_title",
                isPresented: $viewModel.isErrorAlertPresented
            ) {
                Button("scan_enter_error_alert_button_close") { viewModel.retry() }
                Button("scan_enter_error_alert_button_cancel", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "error_base_message")
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

            Spacer(minLength: 24)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("scan_enter_scanning_title")
                    .font(.headline)
                Text("scan_enter_scanning_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}
