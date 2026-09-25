import CachedAsyncImage
import CommunityService
import SwiftUI

struct CommunityAvatar: View {
  let owner: CommunityPost.Owner?
  let avatarURL: (CommunityPost.Owner.Avatar) -> URL

  var body: some View {
    contentView()
  }
}

private extension CommunityAvatar {
  @ViewBuilder
  private func contentView() -> some View {
    CachedAsyncImage(url: owner?.avatar.map(avatarURL)) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      placeholderView()
        .foregroundStyle(Constants.foreground)
    }
    .clipShape(.circle)
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func placeholderView() -> some View {
    Circle().fill(Constants.placeholder)
      .overlay {
        if let name = owner?.nickname, !name.isEmpty {
          Text(String(name.prefix(Constants.initialCount)).uppercased())
            .font(.subheadline.weight(.semibold))
        } else {
          Image(systemName: Constants.person)
        }
      }
  }
}

private enum Constants {
  static let initialCount = 1
  static let person = "person.fill"
  static let placeholder = Color(uiColor: .tertiarySystemFill)
  static let foreground = Color.secondary
}
