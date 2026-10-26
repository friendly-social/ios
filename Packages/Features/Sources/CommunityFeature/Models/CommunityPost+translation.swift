import CommunityService

extension CommunityPost {
  func canTranslate(by accountID: Int64?) -> Bool {
    guard let accountID, let owner, text != nil else { return false }
    return owner.id != accountID
  }
}
