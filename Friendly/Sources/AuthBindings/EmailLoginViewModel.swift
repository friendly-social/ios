import Foundation

@MainActor
@Observable
class EmailLoginViewModel {
    private let worker = EmailAuthWorker()
    private let storage: Storage = .shared
    private let emailCodeFlow: EmailCodeFlow
    private var emailCodeState: EmailCodeFlow.State

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
    private var confirmTask: Task<Authorization, Swift.Error>?

    init() {
        let emailCodeFlow = EmailCodeFlow()
        self.emailCodeFlow = emailCodeFlow
        self.emailCodeState = emailCodeFlow.state()
        emailCodeFlow.observeState { [weak self] state in
            self?.emailCodeState = state
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
        let worker = worker
        sendTask = Task { [weak self] in
            self?.status = .idle
            emailCodeFlow.isSendingCode = true
            defer { emailCodeFlow.isSendingCode = false }

            do {
                let email = try emailCodeFlow.requestEmail()
                try await worker.requestLoginCode(email: email)
                emailCodeFlow.didRequestCode(for: email)
            } catch is CancellationError {
                return
            } catch NetworkClient.AuthEmailError.unknownEmail {
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
        let worker = worker
        let storage = storage
        status = .idle
        emailCodeFlow.isConfirmingCode = true
        defer {
            emailCodeFlow.isConfirmingCode = false
            confirmTask = nil
        }

        do {
            let email = try emailCodeFlow.requestEmail()
            let code = try emailCodeFlow.codeToConfirm()
            let task: Task<Authorization, Swift.Error> = Task {
                try await worker.login(
                    email: email,
                    code: code.int,
                )
            }
            confirmTask = task

            let authorization = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            try Task.checkCancellation()
            guard !task.isCancelled else {
                throw CancellationError()
            }
            storage.clearAuthorization()
            try storage.saveAuthorization(authorization)
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
        case NetworkClient.AuthLoginError.invalidOrExpiredCode:
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
