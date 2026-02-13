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
    
    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

    @Published var state: State = .idle
    @Published var isScannerPresented = false
    @Published var isErrorAlertPresented = false
    @Published var errorMessage: String?
    
    private let onSuccess: () -> Void
    
    init(onSuccess: @escaping () -> Void) {
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
        validate(from: code)
    }

    private func add(friend: AddFriendCommand) {
        state = .loading
        errorMessage = nil
        isErrorAlertPresented = false
        
        let id = friend.id
        let token = friend.token
        Task {
            guard let authorization = try? storage.loadAuthorization() else {
                isErrorAlertPresented = true
                return
            }
            guard let _ = try? await networkClient.friendsAdd(
                authorization: authorization,
                token: token,
                id: id,
            ) else {
                isErrorAlertPresented = true
                return
            }
            onSuccess()
        }
    }
    
    private func validate(from code: String) {
        state = .idle
        errorMessage = nil
        isErrorAlertPresented = false
        
        do {
            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let url = URL(string: trimmed) else {
                throw ScanEnterError.invalidURL
            }

            let deeplink = Deeplink.parseOf(url: url)
            switch deeplink {
            case let .addFriend(id, token):
                add(friend: AddFriendCommand(id: id, token: token))
            case nil:
                throw ScanEnterError.invalidURL
            }
            
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isErrorAlertPresented = true
        }
    }
}

extension ScanToUseAppViewModel {
    func handlePickedImageData(_ data: Data) {
        state = .loading
        errorMessage = nil
        isErrorAlertPresented = false

        Task {
            guard let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                errorMessage = "scan_enter_photo_invalid_image"
                isErrorAlertPresented = true
                return
            }
            
            let codes = cgImage.detectQRCodeStrings()
            guard let code = codes.first, !code.isEmpty else {
                errorMessage = "scan_enter_photo_qr_not_found"
                isErrorAlertPresented = true
                return
            }
            
            handleScanned(code: code)
        }
    }
}

enum ScanEnterError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "scan_enter_invalid_url")
        }
    }
}
