import Foundation

@MainActor
@Observable
class AuthBindingsViewModel {
    var showProviderUnavailableAlert: Bool = false

    func tapAppleAuthorization() {
        showProviderUnavailableAlert = true
    }

    func tapGoogleAuthorization() {
        showProviderUnavailableAlert = true
    }
}
