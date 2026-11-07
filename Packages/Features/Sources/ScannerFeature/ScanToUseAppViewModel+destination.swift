extension ScanToUseAppViewModel {
  enum Destination: Hashable, Identifiable {
    case scanner
    case emailLogin
    case signOut

    var id: Self { self }
  }

  var scannerDestination: Destination? {
    get { destination == .scanner ? .scanner : nil }
    set { if destination == .scanner { destination = newValue } }
  }

  var emailDestination: Destination? {
    get { destination == .emailLogin ? .emailLogin : nil }
    set { if destination == .emailLogin { destination = newValue } }
  }

  var confirmsSignOut: Bool {
    get { destination == .signOut }
    set { if !newValue, destination == .signOut { destination = nil } }
  }

  func openScanner() { destination = .scanner }

  func closeScanner() { scannerDestination = nil }

  func openEmailLogin() { destination = .emailLogin }

  func requestSignOut() { destination = .signOut }
}
