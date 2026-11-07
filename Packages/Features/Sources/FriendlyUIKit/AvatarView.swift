import NukeUI
import SwiftUI

public struct AvatarView: View {
  private let url: URL?
  private let size: CGFloat
  private let openLabel: LocalizedStringResource?
  private let onOpen: ((Image, CGSize?, CGRect) -> Void)?
  private let isPresented: Bool
  @State private var sourceFrame = CGRect.zero
  @Environment(\.colorScheme) private var colorScheme

  public init(
    url: URL?, size: CGFloat, openLabel: LocalizedStringResource? = nil,
    isPresented: Bool = false, onOpen: ((Image, CGSize?, CGRect) -> Void)? = nil
  ) {
    self.url = url
    self.size = size
    self.openLabel = openLabel
    self.isPresented = isPresented
    self.onOpen = onOpen
  }

  public var body: some View { contentView() }
}

private extension AvatarView {
  @ViewBuilder
  private func contentView() -> some View {
    if let url {
      LazyImage(url: url) { state in
        if let image = state.image {
          loadedImage(image, imageSize: state.imageContainer?.image.size)
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

  @ViewBuilder
  private func loadedImage(_ image: Image, imageSize: CGSize?) -> some View {
    if let onOpen, let openLabel {
      Button {
        onOpen(image, imageSize, sourceFrame)
      } label: {
        avatarImage(image)
          .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sourceFrame = $0 }
          .opacity(isPresented ? 0 : 1)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(openLabel))
    } else {
      avatarImage(image)
    }
  }

  private func avatarImage(_ image: Image) -> some View {
    image.resizable().aspectRatio(contentMode: .fill)
      .frame(width: size, height: size).clipShape(.circle)
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
