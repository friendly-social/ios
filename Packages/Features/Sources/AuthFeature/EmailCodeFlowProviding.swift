@MainActor
protocol EmailCodeFlowProviding: AnyObject {
    func emailCodeFlowState() -> EmailCodeFlow.State
    var canConfirm: Bool { get }
}

extension EmailCodeFlowProviding {
    var code: String {
        emailCodeFlowState().code
    }

    var isSendingCode: Bool {
        emailCodeFlowState().isSendingCode
    }

    var isConfirmingCode: Bool {
        emailCodeFlowState().isConfirmingCode
    }

    var remainingSeconds: Int {
        emailCodeFlowState().remainingSeconds
    }

    var isEmailLocked: Bool {
        emailCodeFlowState().isEmailLocked
    }

    var canRequestCode: Bool {
        emailCodeFlowState().canRequestCode
    }

    var canConfirm: Bool {
        emailCodeFlowState().canConfirm
    }

    var formattedTimer: String {
        emailCodeFlowState().formattedTimer
    }
}
