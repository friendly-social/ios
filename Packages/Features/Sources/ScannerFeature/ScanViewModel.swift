//
//  ScanViewModel.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import Dependencies
import Foundation
import FriendAccessService
import Models
import Observation
import PhotosUI
import QRPhotoImportService
import SwiftUI

@MainActor @Observable
final class ScanToUseAppViewModel {
    enum State: Equatable {
        case idle
        case loading
    }
    
    @ObservationIgnored @Dependency(FriendAccessService.self) private var friendAccessService
    @ObservationIgnored @Dependency(QRPhotoImportService.self) private var photoImportService

    var state: State = .idle
    var isScannerPresented = false
    var isErrorAlertPresented = false
    var errorMessage: String?
    
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

    func tapCancelButton() {
        state = .idle
    }

    func handleScanned(code: String) {
        isScannerPresented = false
        validate(from: code)
    }

    private func add(friend: AddFriendCommand) {
        state = .loading
        errorMessage = nil
        isErrorAlertPresented = false
        
        Task {
            guard let _ = try? await friendAccessService.addFriend(friend) else {
                state = .idle
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
    func handlePickedPhoto(_ item: PhotosPickerItem) async {
        state = .loading
        errorMessage = nil
        isErrorAlertPresented = false
        do {
            let code = try await photoImportService.code(item)
            handleScanned(code: code)
        } catch let error as QRPhotoImportService.ImportError {
            photoImportError(error)
        } catch {
            photoImportError(.invalidImage)
        }
    }
}

private extension ScanToUseAppViewModel {
    private func photoImportError(_ error: QRPhotoImportService.ImportError) {
        state = .idle
        errorMessage = switch error {
        case .invalidImage: String(localized: .scanEnterPhotoInvalidImage)
        case .codeNotFound: String(localized: .scanEnterPhotoQrNotFound)
        }
        isErrorAlertPresented = true
    }
}

enum ScanEnterError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: .scanEnterInvalidUrl)
        }
    }
}
