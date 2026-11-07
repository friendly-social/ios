extension NetworkQRCodeViewModel {
  enum Destination: Hashable, Identifiable {
    case scanner
    case replace

    var id: Self { self }
  }

  var scannerDestination: Destination? {
    get { destination == .scanner ? .scanner : nil }
    set {
      if newValue == .scanner || destination == .scanner {
        destination = newValue
      }
    }
  }

  var confirmsReplacement: Bool {
    get { destination == .replace }
    set {
      if !newValue, destination == .replace {
        destination = nil
      }
    }
  }

  func showScanner() { destination = .scanner }

  func requestReplacement() {
    guard activeInvitation != nil else { return }
    destination = .replace
  }
}
