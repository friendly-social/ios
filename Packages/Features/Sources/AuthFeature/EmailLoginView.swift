import SwiftUI

public struct EmailLoginView: View {
    let onSuccess: () -> Void

    public init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }

    @State private var viewModel = EmailLoginViewModel()
    @FocusState private var isCodeInputFocused: Bool

    public var body: some View {
        ScrollView {
            contentView
                .padding(.horizontal, 24)
                .padding(.top, 36)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(String(localized: .emailLoginNavigationTitle))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Group {
                if viewModel.isEmailLocked { confirmCodeButton }
                else { sendCodeButton }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .onAppear { viewModel.start() }
        .onDisappear {
            viewModel.cancelTasks()
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleLabel
            subtitleLabel
            emailTextField
            changeEmailButton
            if viewModel.isEmailLocked {
                verificationCodeInputView
                resendTimerView
                detailsLabel
            }
            statusMessageView
        }
    }

    private var titleLabel: some View {
        Text(.emailLoginTitle)
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitleLabel: some View {
        Text(.emailLoginSubtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailsLabel: some View {
        Text(.emailLoginDetails)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var emailTextField: some View {
        TextField(
            String(localized: .profileEditBindEmailEmailExample),
            text: Binding(
                get: { viewModel.email },
                set: { viewModel.email = $0 }
            )
        )
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .disabled(viewModel.isEmailLocked)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var changeEmailButton: some View {
        if viewModel.isEmailLocked {
            Button {
                viewModel.resetEmailRequest()
            } label: {
                Text(.emailChangeAddress)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var sendCodeButton: some View {
        Button(action: { viewModel.requestCode() }) {
            sendCodeButtonLabel
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .foregroundStyle(.white)
        .tint(.accentColor)
        .opacity(viewModel.canRequestCode ? 1 : 0.5)
        .disabled(!viewModel.canRequestCode)
    }

    @ViewBuilder
    private var sendCodeButtonLabel: some View {
        if viewModel.isSendingCode {
            ProgressView()
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .tint(.white)
        } else {
            Text(.profileEditBindEmailSendCode)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
    }

    @ViewBuilder
    private var resendTimerView: some View {
        if viewModel.remainingSeconds > 0 {
            Text(.emailBindingResendAfter)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            Text(verbatim: viewModel.formattedTimer)
                .font(.headline.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .center)
        } else if viewModel.canRequestCode {
            Button(.emailLoginResendCode) { viewModel.requestCode() }
                .buttonStyle(.borderless)
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var verificationCodeInputView: some View {
        VerificationCodeInputView(
            code: Binding(
                get: { viewModel.code },
                set: { viewModel.updateCode($0) }
            ),
            isFocused: $isCodeInputFocused,
            isError: viewModel.status == .invalidCode,
        )
    }

    private var confirmCodeButton: some View {
        Button(action: {
            Task {
                do {
                    try await viewModel.confirmCode()
                    onSuccess()
                } catch {
                    // The view model already presents the appropriate error state.
                }
            }
        }) {
            confirmCodeButtonLabel
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .foregroundStyle(.white)
        .tint(.accentColor)
        .opacity(viewModel.canConfirm ? 1 : 0.5)
        .disabled(!viewModel.canConfirm)
    }

    @ViewBuilder
    private var confirmCodeButtonLabel: some View {
        if viewModel.isConfirmingCode {
            ProgressView()
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .tint(.white)
        } else {
            Text(.emailLoginConfirm)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
    }

    @ViewBuilder
    private var statusMessageView: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()
        case .success:
            Text(.emailLoginSuccess)
                .font(.footnote)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        case .invalidEmail:
            InlineErrorView(.emailErrorInvalid)
        case .unknownEmail:
            InlineErrorView(.emailLoginErrorUnknown)
        case .invalidCode:
            InlineErrorView(.emailErrorInvalidCode)
        case .networkError:
            InlineErrorView(.profileEditBindEmailError)
        }
    }
}
