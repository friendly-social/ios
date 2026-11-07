//
//  InvitationScannerInputViewModel.swift
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
final class InvitationScannerInputViewModel {
  enum State: Equatable {
    case idle
    case loading
  }

  @ObservationIgnored @Dependency(FriendAccessService.self) private var friendAccessService
  @ObservationIgnored @Dependency(QRPhotoImportService.self) private var photoImportService

  private(set) var state: State = .idle
  var isErrorAlertPresented = false
  private(set) var errorMessage: LocalizedStringResource?

  var acceptsInput: Bool { state == .idle && !isErrorAlertPresented }

  private let onSuccess: () -> Void

  init(onSuccess: @escaping () -> Void) {
    self.onSuccess = onSuccess
  }

  func handleScanned(code: String) {
    state = .idle
    errorMessage = nil
    isErrorAlertPresented = false
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed),
          case let .addFriend(token)? = Deeplink.parseOf(url: url) else {
      presentError(.scanEnterInvalidUrl)
      return
    }
    add(friend: AddFriendCommand(token: token))
  }
}

extension InvitationScannerInputViewModel {
  func handlePasteFailure() {
    guard acceptsInput else { return }
    presentError(.scannerQrcodePasteFailed)
  }

  func handlePickedPhoto(_ item: PhotosPickerItem) async {
    guard acceptsInput, !Task.isCancelled else { return }
    state = .loading
    errorMessage = nil
    isErrorAlertPresented = false
    do {
      let code = try await photoImportService.code(item)
      try Task.checkCancellation()
      handleScanned(code: code)
    } catch {
      if Task.isCancelled || error is CancellationError {
        state = .idle
        return
      }
      photoImportError(error as? QRPhotoImportService.ImportError ?? .invalidImage)
    }
  }
}

private extension InvitationScannerInputViewModel {
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

  private func photoImportError(_ error: QRPhotoImportService.ImportError) {
    let message: LocalizedStringResource = switch error {
    case .invalidImage: .scanEnterPhotoInvalidImage
    case .codeNotFound: .scanEnterPhotoQrNotFound
    }
    presentError(message)
  }

  private func presentError(_ message: LocalizedStringResource) {
    state = .idle
    errorMessage = message
    isErrorAlertPresented = true
  }
}
