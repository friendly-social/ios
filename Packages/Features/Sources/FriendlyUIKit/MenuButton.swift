import SwiftUI
import UIKit

@MainActor
public struct MenuButton: UIViewRepresentable {
  public indirect enum Item {
    case action(title: LocalizedStringResource, systemImage: String, role: Role = .standard, action: @MainActor () -> Void)
    case submenu(title: LocalizedStringResource, message: LocalizedStringResource, systemImage: String, role: Role = .standard, items: [Item])
  }

  public enum Role {
    case standard, destructive
  }

  @Environment(\.isEnabled) private var isEnabled
  private let systemImage: String
  private let accessibilityLabel: LocalizedStringResource
  private let items: [Item]

  public init(systemImage: String, accessibilityLabel: LocalizedStringResource, items: [Item]) {
    self.systemImage = systemImage
    self.accessibilityLabel = accessibilityLabel
    self.items = items
  }
}

extension MenuButton {
  public func makeUIView(context: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.showsMenuAsPrimaryAction = true
    button.tintColor = Constants.tint
    return button
  }

  public func updateUIView(_ button: UIButton, context: Context) {
    button.setImage(UIImage(systemName: systemImage), for: .normal)
    button.accessibilityLabel = String(localized: accessibilityLabel)
    button.isEnabled = isEnabled
    button.menu = UIMenu(children: items.map(makeElement))
  }
}

private extension MenuButton {
  private func makeElement(_ item: Item) -> UIMenuElement {
    switch item {
    case let .action(title, systemImage, role, action):
      UIAction(
        title: String(localized: title), image: UIImage(systemName: systemImage),
        attributes: role == .destructive ? .destructive : []
      ) { _ in action() }
    case let .submenu(title, message, systemImage, role, items):
      UIMenu(
        title: String(localized: title), image: UIImage(systemName: systemImage),
        options: role == .destructive ? .destructive : [],
        children: [UIMenu(title: String(localized: message), options: .displayInline, children: items.map(makeElement))]
      )
    }
  }
}

private enum Constants {
  static let tint = UIColor.secondaryLabel
}
