import Dependencies
import EmailAuthService
import Foundation

@MainActor @Observable
final class EmailBindingViewModel {
  enum Step: Equatable, Sendable {
    case address
    case code(email: String)
    case success(email: String)
  }

  enum Failure: Equatable {
    case addressUnavailable
    case invalidCodeFormat
    case invalidCode
    case unauthorized
    case requestFailed
  }

  private enum Status: Equatable {
    case idle
    case sending
    case confirming
    case failed(Failure)
  }

  @ObservationIgnored @Dependency(EmailAuthService.self) private var service
  private let onLinked: (String) -> Void
  private var status: Status = .idle
  private var operation: Task<Void, Never>?
  private(set) var step: Step = .address
  private(set) var email = ""
  private(set) var code = ""

  init(onLinked: @escaping (String) -> Void) {
    self.onLinked = onLinked
  }

  var isWorking: Bool { status == .sending || status == .confirming }

  var failure: Failure? {
    if case let .failed(failure) = status { return failure }
    if case .code = step, code.count == 8, ConfirmationCode(code) == nil {
      return .invalidCodeFormat
    }
    return nil
  }

  var canSubmit: Bool {
    guard !isWorking, failure != .unauthorized else { return false }
    switch step {
    case .address:
      return EmailCodeFlow.isValidEmail(normalizedEmail) && failure != .addressUnavailable
    case .code: return ConfirmationCode(code) != nil
    case .success: return false
    }
  }

  func updateEmail(_ value: String) {
    guard case .address = step, !isWorking, failure != .unauthorized else { return }
    email = value
    status = .idle
  }

  func updateCode(_ value: String) {
    guard case .code = step, !isWorking, failure != .unauthorized else { return }
    code = ConfirmationCode.sanitize(value)
    status = .idle
  }

  func changeEmail() {
    guard case .code = step, !isWorking, failure != .unauthorized else { return }
    code = ""
    status = .idle
    step = .address
  }

  @discardableResult
  func submit() -> Task<Void, Never>? {
    guard canSubmit else { return nil }
    let service = service
    switch step {
    case .address:
      let address = normalizedEmail
      email = address
      return run(.sending) {
        try await service.requestBindingCode(email: address)
        return .code(email: address)
      }
    case let .code(address):
      guard let confirmation = ConfirmationCode(code) else { return nil }
      let value = confirmation.int
      return run(.confirming) {
        try await service.confirmBinding(email: address, code: value)
        return .success(email: address)
      }
    case .success:
      return nil
    }
  }

  func cancelOperation() {
    operation?.cancel()
    operation = nil
    if isWorking { status = .idle }
  }
}

private extension EmailBindingViewModel {
  private var normalizedEmail: String {
    email.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func run(
    _ loading: Status,
    request: @escaping @Sendable () async throws -> Step
  ) -> Task<Void, Never> {
    status = loading
    let task = Task { [weak self] in
      do {
        try Task.checkCancellation()
        let nextStep = try await request()
        try Task.checkCancellation()
        self?.complete(nextStep)
      } catch {
        guard !Task.isCancelled else { return }
        self?.status = Self.status(for: error)
      }
      self?.operation = nil
    }
    operation = task
    return task
  }

  private func complete(_ nextStep: Step) {
    step = nextStep
    status = .idle
    if case let .success(email) = nextStep { onLinked(email) }
  }

  private static func status(for error: Error) -> Status {
    switch error {
    case is CancellationError: .idle
    case EmailAuthError.alreadyUsed: .failed(.addressUnavailable)
    case EmailAuthError.invalidCode: .failed(.invalidCode)
    case EmailAuthError.unauthorized: .failed(.unauthorized)
    default: .failed(.requestFailed)
    }
  }
}
