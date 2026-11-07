import Observation

@MainActor @Observable
final class ScanToUseAppViewModel {
  var destination: Destination?

  let onEmailLogin: () -> Void
  private let onSignOut: () -> Void
  private let onSuccess: () -> Void

  init(
    onEmailLogin: @escaping () -> Void,
    onSignOut: @escaping () -> Void,
    onSuccess: @escaping () -> Void
  ) {
    self.onEmailLogin = onEmailLogin
    self.onSignOut = onSignOut
    self.onSuccess = onSuccess
  }

  func completeScan() {
    closeScanner()
    onSuccess()
  }

  func signOut() {
    destination = nil
    onSignOut()
  }
}
