import Foundation

@MainActor
final class EmailCodeFlow {
    struct State {
        let email: String
        let code: String
        let isSendingCode: Bool
        let isConfirmingCode: Bool
        let remainingSeconds: Int
        let isEmailLocked: Bool
        let canRequestCode: Bool
        let isEmailValid: Bool
        let canConfirm: Bool
        let formattedTimer: String
    }

    enum Error: Swift.Error {
        case invalidEmail
        case invalidCode
    }

    var email: String = "" {
        didSet { notifyStateChanged() }
    }
    var code: String = "" {
        didSet { notifyStateChanged() }
    }
    var isSendingCode: Bool = false {
        didSet { notifyStateChanged() }
    }
    var isConfirmingCode: Bool = false {
        didSet { notifyStateChanged() }
    }
    var remainingSeconds: Int = 0 {
        didSet { notifyStateChanged() }
    }
    private(set) var requestedEmail: String? {
        didSet { notifyStateChanged() }
    }

    var isEmailLocked: Bool {
        requestedEmail != nil || isSendingCode
    }

    var canRequestCode: Bool {
        remainingSeconds == 0 && !isSendingCode && !isConfirmingCode
    }

    var isEmailValid: Bool {
        let normalized = normalizedEmail
        guard let emailRegex else { return false }
        return normalized.count <= 2048 &&
            (try? emailRegex.wholeMatch(in: normalized)) != nil
    }

    var canConfirm: Bool {
        requestedEmail != nil &&
            !isSendingCode &&
            !isConfirmingCode &&
            ConfirmationCode(code) != nil
    }

    var formattedTimer: String {
        Duration.seconds(remainingSeconds)
            .formatted(.time(pattern: .minuteSecond))
    }

    func state() -> State {
        State(
            email: email,
            code: code,
            isSendingCode: isSendingCode,
            isConfirmingCode: isConfirmingCode,
            remainingSeconds: remainingSeconds,
            isEmailLocked: isEmailLocked,
            canRequestCode: canRequestCode,
            isEmailValid: isEmailValid,
            canConfirm: canConfirm,
            formattedTimer: formattedTimer,
        )
    }

    private var cooldownTask: Task<Void, Never>?
    private var stateChanged: ((State) -> Void)?
    private let emailRegex =
        try? Regex("[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func observeState(_ observer: @escaping (State) -> Void) {
        stateChanged = observer
        observer(state())
    }

    func updateCode(_ value: String) {
        code = ConfirmationCode.sanitize(value)
    }

    func requestEmail() throws -> String {
        if let requestedEmail {
            return requestedEmail
        }
        let normalized = normalizedEmail
        guard isEmailValid else {
            throw Error.invalidEmail
        }
        email = normalized
        return normalized
    }

    func codeToConfirm() throws -> ConfirmationCode {
        guard let code = ConfirmationCode(code) else {
            throw Error.invalidCode
        }
        return code
    }

    func didRequestCode(for email: String) {
        requestedEmail = email
        startCooldown()
    }

    func resetEmailRequest() {
        cooldownTask?.cancel()
        requestedEmail = nil
        remainingSeconds = 0
        code = ""
    }

    func cancelCooldown() {
        cooldownTask?.cancel()
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        cooldownTask = Task { [weak self] in
            self?.remainingSeconds = 60
            while let remainingSeconds = self?.remainingSeconds,
                  remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.remainingSeconds = remainingSeconds - 1
            }
        }
    }

    private func notifyStateChanged() {
        stateChanged?(state())
    }
}
