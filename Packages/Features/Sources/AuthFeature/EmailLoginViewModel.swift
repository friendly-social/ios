import Dependencies
import EmailAuthService
import Foundation

@MainActor
@Observable
class EmailLoginViewModel {
    @ObservationIgnored @Dependency(EmailAuthService.self) private var service
    private let emailCodeFlow: EmailCodeFlow
    private var stateRevision = 0
    private var emailCodeState: EmailCodeFlow.State {
        _ = stateRevision
        return emailCodeFlow.state()
    }

    var email: String {
        get { emailCodeState.email }
        set {
            emailCodeFlow.email = newValue
            clearStatus()
        }
    }

    var canConfirm: Bool {
        emailCodeState.isEmailValid &&
            !emailCodeState.isSendingCode &&
            !emailCodeState.isConfirmingCode &&
            ConfirmationCode(emailCodeState.code) != nil
    }

    var status: Status = .idle

    private var sendTask: Task<Void, Never>?
    private var confirmTask: Task<Void, Swift.Error>?

    init() {
        self.emailCodeFlow = EmailCodeFlow()
    }

    private var isObserving = false

    func start() {
        guard !isObserving else { return }
        isObserving = true
        emailCodeFlow.observeState { [weak self] _ in
            self?.stateRevision &+= 1
        }
    }

    func updateCode(_ value: String) {
        emailCodeFlow.updateCode(value)
        clearStatus()
    }

    func requestCode() {
        guard emailCodeFlow.canRequestCode else { return }
        sendTask?.cancel()
        let emailCodeFlow = emailCodeFlow
        let service = service
        sendTask = Task { [weak self] in
            self?.status = .idle
            emailCodeFlow.isSendingCode = true
            defer { emailCodeFlow.isSendingCode = false }

            do {
                let email = try emailCodeFlow.requestEmail()
                try await service.requestLoginCode(email)
                emailCodeFlow.didRequestCode(for: email)
            } catch is CancellationError {
                return
            } catch EmailAuthError.unknownEmail {
                self?.status = .unknownEmail
            } catch EmailCodeFlow.Error.invalidEmail {
                self?.status = .invalidEmail
            } catch {
                self?.status = .networkError
            }
        }
    }

    func confirmCode() async throws {
        guard canConfirm else {
            throw EmailCodeFlow.Error.invalidCode
        }
        confirmTask?.cancel()
        let emailCodeFlow = emailCodeFlow
        let service = service
        status = .idle
        emailCodeFlow.isConfirmingCode = true
        defer {
            emailCodeFlow.isConfirmingCode = false
            confirmTask = nil
        }

        do {
            let email = try emailCodeFlow.requestEmail()
            let code = try emailCodeFlow.codeToConfirm()
            let task: Task<Void, Swift.Error> = Task {
                try await service.login(email, code.int)
            }
            confirmTask = task

            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            try Task.checkCancellation()
            guard !task.isCancelled else {
                throw CancellationError()
            }
            status = .success
        } catch {
            updateStatus(for: error)
            throw error
        }
    }

    func resetEmailRequest() {
        sendTask?.cancel()
        confirmTask?.cancel()
        emailCodeFlow.resetEmailRequest()
        status = .idle
    }

    func cancelTasks() {
        sendTask?.cancel()
        confirmTask?.cancel()
        emailCodeFlow.cancelCooldown()
    }

    private func clearStatus() {
        if status != .idle {
            status = .idle
        }
    }

    private func updateStatus(for error: Swift.Error) {
        switch error {
        case is CancellationError:
            break
        case EmailAuthError.invalidCode:
            status = .invalidCode
        case EmailCodeFlow.Error.invalidEmail:
            status = .invalidEmail
        case EmailCodeFlow.Error.invalidCode:
            status = .invalidCode
        default:
            status = .networkError
        }
    }

    enum Status {
        case idle
        case success
        case invalidEmail
        case unknownEmail
        case invalidCode
        case networkError
    }
}

extension EmailLoginViewModel: EmailCodeFlowProviding {
    func emailCodeFlowState() -> EmailCodeFlow.State {
        emailCodeState
    }
}
