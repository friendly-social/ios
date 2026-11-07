import CoreTransferable
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct InvitationPasteButtonView: UIViewRepresentable {
  private let onPaste: (String) -> Void
  private let onFailure: () -> Void

  init(onPaste: @escaping (String) -> Void, onFailure: @escaping () -> Void) {
    self.onPaste = onPaste
    self.onFailure = onFailure
  }

  func makeCoordinator() -> Coordinator { .init(onPaste: onPaste, onFailure: onFailure) }

  func makeUIView(context: Context) -> UIPasteControl {
    let configuration = UIPasteControl.Configuration()
    configuration.cornerStyle = .capsule
    configuration.displayMode = .iconAndLabel
    configuration.baseBackgroundColor = Constants.backgroundColor
    configuration.baseForegroundColor = Constants.foregroundColor
    let control = UIPasteControl(configuration: configuration)
    control.target = context.coordinator
    return control
  }

  func updateUIView(_ control: UIPasteControl, context: Context) {
    context.coordinator.onPaste = onPaste
    context.coordinator.onFailure = onFailure
    let isEnabled = context.environment.isEnabled
    control.isUserInteractionEnabled = isEnabled
    if !isEnabled {
      control.target = nil
    } else if control.target == nil {
      control.target = context.coordinator
    }
  }

  final class Coordinator: UIResponder {
    var onPaste: (String) -> Void
    var onFailure: () -> Void

    init(onPaste: @escaping (String) -> Void, onFailure: @escaping () -> Void) {
      self.onPaste = onPaste
      self.onFailure = onFailure
      super.init()
      pasteConfiguration = .init(acceptableTypeIdentifiers: Constants.types)
    }

    override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
      supportedProvider(in: itemProviders) != nil
    }

    override func paste(itemProviders: [NSItemProvider]) {
      guard let provider = supportedProvider(in: itemProviders) else {
        onFailure()
        return
      }
      _ = provider.loadTransferable(type: PastedInvitationLink.self) { [weak self] result in
        Task { @MainActor [weak self] in
          switch result {
          case let .success(link): self?.onPaste(link.text)
          case .failure: self?.onFailure()
          }
        }
      }
    }
  }
}

private extension InvitationPasteButtonView.Coordinator {
  private func supportedProvider(in providers: [NSItemProvider]) -> NSItemProvider? {
    providers.first { provider in
      Constants.types.contains { provider.hasItemConformingToTypeIdentifier($0) }
    }
  }
}

private struct PastedInvitationLink: Transferable {
  let text: String

  static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation(importing: { (url: URL) in Self(text: url.absoluteString) })
    ProxyRepresentation(importing: { (text: String) in Self(text: text) })
  }
}

private enum Constants {
  static let types = [UTType.url.identifier, UTType.plainText.identifier]
  static let backgroundColor = UIColor.systemBlue
  static let foregroundColor = UIColor.white
}
