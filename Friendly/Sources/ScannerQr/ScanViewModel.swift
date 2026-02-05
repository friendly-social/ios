//
//  ScanViewModel.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import Foundation
import SwiftUI

@MainActor
final class ScanToUseAppViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
    }

    @Published var state: State = .idle
    @Published var isScannerPresented = false
    @Published var isErrorAlertPresented = false
    @Published var errorMessage: String?

    private let onSuccess: (Bool) -> Void

    private var lastScannedCode: String?

    init(onSuccess: @escaping (Bool) -> Void) {
        self.onSuccess = onSuccess
    }

    func openScanner() {
        guard state != .loading else { return }
        isScannerPresented = true
    }

    func closeScanner() {
        isScannerPresented = false
    }

    func handleScanned(code: String) {
        isScannerPresented = false
        lastScannedCode = code
        validate(code: code)
    }

    func retry() {
        guard let code = lastScannedCode else { return }
        validate(code: code)
    }

    private func validate(code: String) {
        guard state != .loading else { return }
        state = .loading
        errorMessage = nil
        isErrorAlertPresented = false

        Task {
            do {
                // Проверить код, записать его на бек
                state = .idle
                onSuccess(true)
            } catch {
                state = .idle
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isErrorAlertPresented = true
            }
        }
    }
}
