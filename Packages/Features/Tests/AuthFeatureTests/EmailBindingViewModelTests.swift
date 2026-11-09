@testable import AuthFeature
import Dependencies
import EmailAuthService
import Testing

@MainActor
struct EmailBindingViewModelTests {
  @Test func sendingRequiresAValidAddress() async {
    var service = EmailAuthService()
    service.requestBindingCode = { _ in }
    let model = makeModel(service)
    for invalid in ["", "286181", "kinokot@", "kinokot@example"] {
      model.updateEmail(invalid)
      #expect(!model.canSubmit)
      #expect(model.submit() == nil)
    }
    model.updateEmail("  kinokot@example.com  ")
    #expect(model.canSubmit)
    await model.submit()?.value
    #expect(model.step == .code(email: "kinokot@example.com"))
  }

  @Test func canChangeAnUnavailableAddressAndRequestCode() async {
    var service = EmailAuthService()
    service.requestBindingCode = { email in
      if email == "taken@example.com" { throw EmailAuthError.alreadyUsed }
    }
    let model = makeModel(service)
    model.updateEmail("taken@example.com")
    await model.submit()?.value
    #expect(model.step == .address)
    #expect(model.failure == .addressUnavailable)
    #expect(!model.canSubmit)
    model.updateEmail("  available@example.com  ")
    await model.submit()?.value
    #expect(model.step == .code(email: "available@example.com"))
    #expect(model.failure == nil)
  }

  @Test func rejectedCodeStaysEditableAndSuccessNotifiesTheParent() async {
    var service = EmailAuthService()
    service.requestBindingCode = { _ in }
    service.confirmBinding = { _, code in
      if code != 12_345_678 { throw EmailAuthError.invalidCode }
    }
    var linked: String?
    let model = makeModel(service) { linked = $0 }
    model.updateEmail("kinokot@example.com")
    await model.submit()?.value
    model.updateCode("0123-4567")
    #expect(model.failure == .invalidCodeFormat)
    #expect(model.submit() == nil)
    model.updateCode("1234-5679")
    await model.submit()?.value
    #expect(model.failure == .invalidCode)
    #expect(model.code == "12345679")
    model.updateCode("1234-5678")
    await model.submit()?.value
    #expect(model.step == .success(email: "kinokot@example.com"))
    #expect(linked == "kinokot@example.com")
  }

  @Test func cancellationDoesNotAdvanceToTheCodeStep() async {
    var service = EmailAuthService()
    service.requestBindingCode = { _ in try await Task.sleep(for: .seconds(10)) }
    let model = makeModel(service)
    model.updateEmail("kinokot@example.com")
    let request = model.submit()
    #expect(model.isWorking)
    #expect(model.submit() == nil)
    model.cancelOperation()
    await request?.value
    #expect(model.step == .address)
    #expect(model.failure == nil)
    #expect(model.canSubmit)
  }
}

private extension EmailBindingViewModelTests {
  private func makeModel(
    _ service: EmailAuthService,
    onLinked: @escaping (String) -> Void = { _ in }
  ) -> EmailBindingViewModel {
    withDependencies {
      $0[EmailAuthService.self] = service
    } operation: {
      EmailBindingViewModel(onLinked: onLinked)
    }
  }
}
