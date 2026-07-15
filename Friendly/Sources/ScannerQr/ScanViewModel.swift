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

    struct Alert: Equatable {
        let title: LocalizedStringResource
        let message: LocalizedStringResource
    }

    private enum InviteLinkInputSource {
        case qr
        case textField
    }
    
    @Published var state: State = .idle
    @Published var isScannerPresented = false
    @Published var alert: Alert?
    @Published var inviteLinkText = ""

    private let onSuccess: () -> Void
    private let addFriendService: AddFriendService = .shared

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
        let text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let command = addFriendCommand(from: text) else {
            alert = .invalidLinkFromQr
            return
        }
        add(friend: command)
    }

    func handleEnteredInviteLinkText() {
        guard let command = addFriendCommand(from: inviteLinkText) else {
            alert = .invalidLinkFromTextField
            return
        }
        add(friend: command)
    }

    func resetState() {
        state = .idle
        alert = nil
    }

    private func addFriendCommand(from urlString: String) -> AddFriendCommand? {
        let deeplink = URL(string: urlString).flatMap(Deeplink.parseOf(url:))
        return switch deeplink {
        case let .addFriend(id, token):
            AddFriendCommand(id: id, token: token)
        case nil:
            nil
        }
    }

    private func add(friend: AddFriendCommand) {
        state = .loading
        Task {
            do {
                try await addFriendService.add(friend)
                onSuccess()
            } catch {
                alert = .unknownError
            }
        }
    }
}

extension ScanToUseAppViewModel {
    func handlePickedImageData(_ data: Data) {
        state = .loading
        Task {
            guard let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                alert = .photoInvalidImage(title: .scanEnterErrorAlertTitle)
                return
            }

            let codes = cgImage.detectQRCodeStrings()
            guard let code = codes.first, !code.isEmpty else {
                alert = .photoQrNotFound
                return
            }

            state = .idle
            handleScanned(code: code)
        }
    }
}

extension ScanToUseAppViewModel.Alert {
    static var unknownError: Self {
        Self(
            title: .scanEnterErrorAlertTitleDefault,
            message: .scanEnterErrorAlertDescriptionDefault,
        )
    }

    static var invalidLinkFromQr: Self {
        Self(
            title: .invalidLink,
            message: .scanEnterInvalidLinkFromQr,
        )
    }

    static var invalidLinkFromTextField: Self {
        Self(
            title: .invalidLink,
            message: .scanEnterInvalidLinkFromTextField,
        )
    }
    
    static var photoQrNotFound: Self {
        Self(
            title: .scanEnterErrorAlertTitle,
            message: .scanEnterPhotoQrNotFound,
        )
    }
    
    static func photoInvalidImage(title: LocalizedStringResource) -> Self {
        Self(title: title, message: .scanEnterPhotoInvalidImage)
    }
 }
