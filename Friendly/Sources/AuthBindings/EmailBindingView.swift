import SwiftUI

struct EmailBindingView: View {
    let onSuccess: (String) -> Void

    @State private var viewModel = EmailBindingViewModel()
    @FocusState private var isCodeInputFocused: Bool

    var body: some View {
        ScrollView {
            contentView
                .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(String(localized: .profileEditBindEmailSheetTitle))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.cancelTasks()
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleLabel
            subtitleLabel
            detailsLabel
            emailTextField
            changeEmailButton
            sendCodeButton
            resendTimerView
            verificationCodeInputView
            confirmCodeButton
            statusMessageView
        }
    }

    private var titleLabel: some View {
        Text(.profileEditBindEmailTitle)
            .font(.title3)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var subtitleLabel: some View {
        Text(.profileEditBindEmailSubtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var detailsLabel: some View {
        Text(.emailBindingDetails)
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
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .disabled(viewModel.isEmailLocked)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canRequestCode)
    }

    @ViewBuilder
    private var sendCodeButtonLabel: some View {
        if viewModel.isSendingCode {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        } else {
            Text(.profileEditBindEmailSendCode)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
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
                    let email = try await viewModel.confirmCode()
                    onSuccess(email)
                } catch {
                    // The view model exposes the error through its status.
                }
            }
        }) {
            confirmCodeButtonLabel
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canConfirm)
    }

    @ViewBuilder
    private var confirmCodeButtonLabel: some View {
        if viewModel.isConfirmingCode {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        } else {
            Text(.profileEditBindEmailConfirm)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var statusMessageView: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()
        case .success:
            Text(.profileEditBindEmailSuccess)
                .font(.footnote)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        case .invalidEmail:
            InlineErrorView(.emailErrorInvalid)
        case .alreadyUsed:
            InlineErrorView(.emailBindingErrorUsed)
        case .invalidCode:
            InlineErrorView(.emailErrorInvalidCode)
        case .unauthorized:
            InlineErrorView(.emailErrorUnauthorized)
        case .networkError:
            InlineErrorView(.profileEditBindEmailError)
        }
    }
}
