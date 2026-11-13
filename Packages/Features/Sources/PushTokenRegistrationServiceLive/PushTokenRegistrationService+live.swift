import Dependencies
import PushTokenRegistrationService

private extension PushTokenRegistrationService {
  static func live() -> Self {
    let service = PushTokenRegistrationServiceLive()
    return Self(
      upload: { try await service.upload(firebaseToken: $0, authorization: $1) },
      reset: { await service.reset() }
    )
  }
}

extension PushTokenRegistrationService: DependencyKey {
  public static var liveValue: Self { .live() }
}
