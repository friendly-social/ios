import Foundation

@MainActor
@Observable
class EmailBindingViewModel {
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

    var status: Status = .idle

    private var sendTask: Task<Void, Never>?
    private var confirmTask: Task<Void, Swift.Error>?

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
        let storage = storage
        sendTask = Task { [weak self] in
            self?.status = .idle
            emailCodeFlow.isSendingCode = true
            defer { emailCodeFlow.isSendingCode = false }

            do {
                let email = try emailCodeFlow.requestEmail()
                let authorization = try storage.loadAuthorization()
                try await worker.requestBindingCode(
                    authorization: authorization,
                    email: email,
                )
                emailCodeFlow.didRequestCode(for: email)
            } catch is CancellationError {
                return
            } catch NetworkClient.EmailLinkError.alreadyUsed {
                self?.status = .alreadyUsed
            } catch NetworkClient.EmailLinkError.unauthorized {
                self?.status = .unauthorized
            } catch EmailCodeFlow.Error.invalidEmail {
                self?.status = .invalidEmail
            } catch {
                self?.status = .networkError
            }
        }
    }

    func confirmCode() async throws -> String {
        guard emailCodeFlow.canConfirm else {
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
            guard let email = emailCodeFlow.requestedEmail else {
                throw EmailCodeFlow.Error.invalidEmail
            }
            let code = try emailCodeFlow.codeToConfirm()
            let authorization = try storage.loadAuthorization()
            let task: Task<Void, Swift.Error> = Task {
                try await worker.confirmBinding(
                    authorization: authorization,
                    code: code.int,
                )
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
            return email
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
        case NetworkClient.EmailConfirmError.invalidOrExpiredCode:
            status = .invalidCode
        case NetworkClient.EmailConfirmError.unauthorized:
            status = .unauthorized
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
        case alreadyUsed
        case invalidCode
        case unauthorized
        case networkError
    }
}

extension EmailBindingViewModel: EmailCodeFlowProviding {
    func emailCodeFlowState() -> EmailCodeFlow.State {
        emailCodeState
    }
}
