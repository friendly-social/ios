import SwiftUI

public struct ActionCard: View {
  private let title: LocalizedStringResource
  private let message: LocalizedStringResource
  private let systemImage: String
  private let backgroundColor: Color
  private let foregroundColor: Color
  private let action: () -> Void

  public init(
    title: LocalizedStringResource,
    message: LocalizedStringResource,
    systemImage: String,
    backgroundColor: Color,
    foregroundColor: Color,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.message = message
    self.systemImage = systemImage
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      labelView()
        .foregroundStyle(foregroundColor)
        .multilineTextAlignment(.leading)
        .padding(Constants.padding)
        .background(backgroundColor, in: .rect(cornerRadius: Constants.radius))
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

private extension ActionCard {
  private func labelView() -> some View {
    HStack(spacing: Constants.spacing) {
      HStack(alignment: .firstTextBaseline, spacing: Constants.spacing) {
        Image(systemName: systemImage)
          .font(.headline)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: Constants.spacing) {
          Text(title).font(.headline)
          Text(message).font(.subheadline)
        }
      }
      Spacer(minLength: Constants.minimumSpacing)
      Image(systemName: Constants.chevron)
        .accessibilityHidden(true)
    }
  }
}

private enum Constants {
  static let padding: CGFloat = 20
  static let radius: CGFloat = 26
  static let spacing: CGFloat = 8
  static let minimumSpacing: CGFloat = 0
  static let chevron = "chevron.right"
}
