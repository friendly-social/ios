import Foundation

@MainActor
@Observable
class EmailBindingViewModel {
    private let networkClient: NetworkClient = .meetacy
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
    private var confirmTask: Task<Void, Never>?

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
        let networkClient = networkClient
        let storage = storage
        sendTask = Task { [weak self] in
            self?.status = .idle
            emailCodeFlow.isSendingCode = true
            defer { emailCodeFlow.isSendingCode = false }

            do {
                let email = try emailCodeFlow.requestEmail()
                let authorization = try storage.loadAuthorization()
                try await networkClient.emailLink(
                    authorization: authorization,
                    email: email,
                )
                try Task.checkCancellation()
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

    func confirmCode(onSuccess: @escaping (String) -> Void) {
        guard emailCodeFlow.canConfirm else { return }
        confirmTask?.cancel()
        let emailCodeFlow = emailCodeFlow
        let networkClient = networkClient
        let storage = storage
        confirmTask = Task { [weak self] in
            self?.status = .idle
            emailCodeFlow.isConfirmingCode = true
            defer { emailCodeFlow.isConfirmingCode = false }

            do {
                guard let email = emailCodeFlow.requestedEmail else {
                    throw EmailCodeFlow.Error.invalidEmail
                }
                let code = try emailCodeFlow.codeToConfirm()
                let authorization = try storage.loadAuthorization()
                try await networkClient.emailConfirm(
                    authorization: authorization,
                    code: code.int,
                )
                try Task.checkCancellation()
                self?.status = .success
                onSuccess(email)
            } catch is CancellationError {
                return
            } catch NetworkClient.EmailConfirmError.invalidOrExpiredCode {
                self?.status = .invalidCode
            } catch NetworkClient.EmailConfirmError.unauthorized {
                self?.status = .unauthorized
            } catch EmailCodeFlow.Error.invalidCode {
                self?.status = .invalidCode
            } catch {
                self?.status = .networkError
            }
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
