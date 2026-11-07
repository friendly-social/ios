extension NetworkQRCodeViewModel {
  enum Destination: Equatable {
    case replace
  }

  var confirmsReplacement: Bool {
    get { destination == .replace }
    set { if !newValue, destination == .replace { destination = nil } }
  }

  func requestReplacement() {
    guard activeInvitation != nil else { return }
    destination = .replace
  }
}
