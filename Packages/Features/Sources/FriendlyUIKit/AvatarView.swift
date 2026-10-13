import NukeUI
import SwiftUI

public struct AvatarView: View {
  private let url: URL?
  private let size: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  public init(url: URL?, size: CGFloat) {
    self.url = url
    self.size = size
  }

  public var body: some View { contentView() }
}

private extension AvatarView {
  @ViewBuilder
  private func contentView() -> some View {
    if let url {
      LazyImage(url: url) { state in
        if let image = state.image {
          image.resizable().aspectRatio(contentMode: .fill)
            .frame(width: size, height: size).clipShape(.circle)
        } else {
          placeholderView().overlay {
            ZStack {
              Circle().fill(.ultraThinMaterial)
              ProgressView()
            }
          }
        }
      }
    } else {
      placeholderView()
    }
  }

  private func placeholderView() -> some View {
    Image(systemName: Constants.person)
      .resizable().scaledToFit()
      .frame(width: size, height: size)
      .background(Constants.background)
      .foregroundStyle(Constants.foreground.gradient.opacity(
        colorScheme == .light ? Constants.lightOpacity : Constants.darkOpacity))
      .clipShape(.circle)
  }
}

private enum Constants {
  static let person = "person.circle.fill"
  static let background = Color.white
  static let foreground = Color.gray
  static let lightOpacity = 0.5
  static let darkOpacity = 1.0
}
