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
        let title: String
        let message: String?

        init(title: String, message: String? = nil) {
            self.title = title
            self.message = message
        }
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
    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

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
                let authorization = try storage.loadAuthorization()
                try await networkClient.friendsAdd(
                   authorization: authorization,
                   token: friend.token,
                   id: friend.id
               )
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
                alert = Alert(
                    title: String(localized: "scan_enter_error_alert_title"),
                    message: String(localized: "scan_enter_photo_invalid_image"),
                )
                return
            }

            let codes = cgImage.detectQRCodeStrings()
            guard let code = codes.first, !code.isEmpty else {
                alert = Alert(
                    title: String(localized: "scan_enter_error_alert_title"),
                    message: String(localized: "scan_enter_photo_qr_not_found"),
                )
                return
            }

            state = .idle
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

extension ScanToUseAppViewModel.Alert {
    static var unknownError: Self {
        Self(
            title: String(localized: "scan_enter_error_alert_title_default"),
            message: String(localized: "scan_enter_error_alert_description_default"),
        )
    }

    static var invalidLinkFromQr: Self {
        Self(
            title: String(localized: "invalid_link"),
            message: String(localized: "scan_enter_invalid_link_from_qr"),
        )
    }

    static var invalidLinkFromTextField: Self {
        Self(
            title: String(localized: "invalid_link"),
            message: String(localized: "scan_enter_invalid_link_from_text_field"),
        )
    }

    static var photoInvalidImage: Self {
        Self(
            title: String(localized: "scan_enter_error_alert_title_default"),
            message: String(localized: "scan_enter_photo_invalid_image"),
        )
     }
 }
