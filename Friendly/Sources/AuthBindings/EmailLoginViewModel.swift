import Foundation

@MainActor
@Observable
class EmailLoginViewModel {
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

    var canConfirm: Bool {
        emailCodeState.isEmailValid &&
            !emailCodeState.isSendingCode &&
            !emailCodeState.isConfirmingCode &&
            ConfirmationCode(emailCodeState.code) != nil
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
        sendTask = Task { [weak self] in
            self?.status = .idle
            emailCodeFlow.isSendingCode = true
            defer { emailCodeFlow.isSendingCode = false }

            do {
                let email = try emailCodeFlow.requestEmail()
                try await networkClient.authEmail(email: email)
                try Task.checkCancellation()
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

    func confirmCode(onSuccess: @escaping () -> Void) {
        guard canConfirm else { return }
        confirmTask?.cancel()
        let emailCodeFlow = emailCodeFlow
        let networkClient = networkClient
        let storage = storage
        confirmTask = Task { [weak self] in
            self?.status = .idle
            emailCodeFlow.isConfirmingCode = true
            defer { emailCodeFlow.isConfirmingCode = false }

            do {
                let email = try emailCodeFlow.requestEmail()
                let code = try emailCodeFlow.codeToConfirm()
                let authorization = try await networkClient.authLogin(
                    email: email,
                    code: code.int,
                )
                try Task.checkCancellation()
                storage.clearAuthorization()
                try storage.saveAuthorization(authorization)
                self?.status = .success
                onSuccess()
            } catch is CancellationError {
                return
            } catch NetworkClient.AuthLoginError.invalidOrExpiredCode {
                self?.status = .invalidCode
            } catch EmailCodeFlow.Error.invalidEmail {
                self?.status = .invalidEmail
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
