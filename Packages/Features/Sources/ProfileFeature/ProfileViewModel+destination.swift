import Foundation
import SwiftUI

extension ProfileViewModel {
  enum Destination: Hashable, Identifiable {
    case edit
    case invitation
    case commonFriends
    case photo(Photo)

    var id: Self { self }
  }

  struct Photo: Hashable {
    let id: URL
    let image: Image
    let imageSize: CGSize?
    let sourceFrame: CGRect

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
  }

  var sheetDestination: Destination? {
    get {
      switch destination {
      case .edit, .invitation: destination
      default: nil
      }
    }
    set {
      if let newValue { destination = newValue }
      else if sheetDestination != nil { destination = nil }
    }
  }

  var photoDestination: Destination? {
    get { if case .photo = destination { destination } else { nil } }
    set {
      if let newValue { destination = newValue }
      else if photoDestination != nil { destination = nil }
    }
  }

  var navigationDestination: Destination? {
    get { if case .commonFriends = destination { destination } else { nil } }
    set {
      if let newValue { destination = newValue }
      else if navigationDestination != nil { destination = nil }
    }
  }

  func showProfileFriends() {
    guard commonFriendsPreview != nil else { return }
    destination = .commonFriends
  }

  func showAvatar(_ image: Image, imageSize: CGSize?, sourceFrame: CGRect) {
    guard case let .success(profile) = state, let url = profile.info.avatarUrl else { return }
    destination = .photo(Photo(id: url, image: image, imageSize: imageSize, sourceFrame: sourceFrame))
  }
}
