public import ProfileFormService
public import Dependencies

extension ProfileFormService {
  static func live() -> Self {
    let live = ProfileFormServiceLive()
    return .init(
      loadAvatar: { try await live.loadAvatar($0) },
      uploadAvatar: { try await live.uploadAvatar($0) },
      signUp: { try await live.signUp(nickname: $0, description: $1, interests: $2, avatar: $3, socialLink: $4) },
      updateProfile: { try await live.updateProfile(nickname: $0, description: $1, interests: $2, avatar: $3, socialLink: $4) },
      unlinkEmail: { try await live.unlinkEmail() }
    )
  }
}

extension ProfileFormService: DependencyKey {
  public static var liveValue: Self { .live() }
}
