import AccountStorageService
import AuthApi
import Dependencies
import Models
import PushTokenRegistrationService
import PushTokenRegistrationServiceLive
import Synchronization
import Testing

struct PushTokenRegistrationServiceTests {
  @Test(arguments: [false, true])
  func offlineFailureIsRetriedInTheSameOrNextLaunch(newLaunch: Bool) async throws {
    let authorization = try authorization()
    let calls = Mutex(0)
    var api = AuthApi()
    api.registerFirebaseToken = { _, token in
      #expect(token == "fcm-token")
      try calls.withLock { count in
        count += 1
        if count == 1 { throw AuthApi.FirebaseRegistrationError.ioError }
      }
    }
    try await withDependencies {
      $0[AccountStorageService.self] = accounts(authorization)
      $0[AuthApi.self] = api
    } operation: {
      let initial = PushTokenRegistrationService.liveValue
      await #expect(throws: AuthApi.FirebaseRegistrationError.ioError) {
        try await initial.upload(firebaseToken: "fcm-token", authorization: authorization)
      }
      let retry = newLaunch ? PushTokenRegistrationService.liveValue : initial
      try await retry.upload(firebaseToken: "fcm-token", authorization: authorization)
      try await retry.upload(firebaseToken: "fcm-token", authorization: authorization)
      #expect(calls.withLock { $0 } == 2)
    }
  }

  @Test func tokenRotationUploadsTheNewToken() async throws {
    let authorization = try authorization()
    let uploaded = Mutex([String]())
    var api = AuthApi()
    api.registerFirebaseToken = { _, token in uploaded.withLock { $0.append(token) } }
    try await withDependencies {
      $0[AccountStorageService.self] = accounts(authorization)
      $0[AuthApi.self] = api
    } operation: {
      let synchronizer = PushTokenRegistrationService.liveValue
      try await synchronizer.upload(firebaseToken: "first", authorization: authorization)
      try await synchronizer.upload(firebaseToken: "second", authorization: authorization)
      try await synchronizer.upload(firebaseToken: "second", authorization: authorization)
      #expect(uploaded.withLock { $0 } == ["first", "second"])
    }
  }

  @Test func revokedRegistrationCanBeUploadedAgain() async throws {
    let authorization = try authorization()
    let calls = Mutex(0)
    var api = AuthApi()
    api.registerFirebaseToken = { _, _ in calls.withLock { $0 += 1 } }
    try await withDependencies {
      $0[AccountStorageService.self] = accounts(authorization)
      $0[AuthApi.self] = api
    } operation: {
      let synchronizer = PushTokenRegistrationService.liveValue
      try await synchronizer.upload(firebaseToken: "fcm-token", authorization: authorization)
      await synchronizer.reset()
      try await synchronizer.upload(firebaseToken: "fcm-token", authorization: authorization)
      #expect(calls.withLock { $0 } == 2)
    }
  }

  @Test func accountChangeDuringUploadDiscardsTheAcknowledgement() async throws {
    let first = try authorization()
    let second = try authorization(id: 8, character: "s")
    let current = Mutex(first)
    var accounts = AccountStorageService()
    accounts.loadAuthorization = { current.withLock { $0 } }
    accounts.shareNotificationSession = { _ in }
    let calls = Mutex(0)
    var api = AuthApi()
    api.registerFirebaseToken = { authorization, _ in
      calls.withLock { $0 += 1 }
      if authorization.id == first.id { current.withLock { $0 = second } }
    }
    try await withDependencies {
      $0[AccountStorageService.self] = accounts
      $0[AuthApi.self] = api
    } operation: {
      let synchronizer = PushTokenRegistrationService.liveValue
      await #expect(throws: CancellationError.self) {
        try await synchronizer.upload(firebaseToken: "fcm-token", authorization: first)
      }
      try await synchronizer.upload(firebaseToken: "fcm-token", authorization: second)
      #expect(calls.withLock { $0 } == 2)
    }
  }

  @Test func accountChangeWhileSharingDoesNotUploadAnOldToken() async throws {
    let first = try authorization()
    let second = try authorization(id: 8, character: "s")
    let current = Mutex(first)
    var accounts = AccountStorageService()
    accounts.loadAuthorization = { current.withLock { $0 } }
    accounts.shareNotificationSession = { _ in current.withLock { $0 = second } }
    var api = AuthApi()
    api.registerFirebaseToken = { _, _ in Issue.record("A stale session must not upload a token") }
    try await withDependencies {
      $0[AccountStorageService.self] = accounts
      $0[AuthApi.self] = api
    } operation: {
      let synchronizer = PushTokenRegistrationService.liveValue
      await #expect(throws: CancellationError.self) {
        try await synchronizer.upload(firebaseToken: "fcm-token", authorization: first)
      }
    }
  }
}

private extension PushTokenRegistrationServiceTests {
  private func authorization(id: Int64 = 7, character: Character = "t") throws -> Authorization {
    try Authorization(
      token: Token(String(repeating: String(character), count: Token.length)),
      id: UserId(id),
      accessHash: UserAccessHash(String(repeating: "h", count: UserAccessHash.length))
    )
  }

  private func accounts(_ authorization: Authorization) -> AccountStorageService {
    var accounts = AccountStorageService()
    accounts.loadAuthorization = { authorization }
    accounts.shareNotificationSession = { _ in }
    return accounts
  }
}
