import SwiftUI

struct EmailBindingView: View {
    let onSuccess: (String) -> Void

    @State private var viewModel = EmailBindingViewModel()
    @FocusState private var isCodeInputFocused: Bool

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("profile_edit_bind_email_title")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                Text("profile_edit_bind_email_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                Text("email_binding_details")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                TextField(
                    String(localized: "profile_edit_bind_email_email_example"),
                    text: $viewModel.email
                )
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(viewModel.isEmailLocked)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if viewModel.isEmailLocked {
                    Button("email_change_address") {
                        viewModel.resetEmailRequest()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Button(action: { viewModel.requestCode() }) {
                    if viewModel.isSendingCode {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Text("profile_edit_bind_email_send_code")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canRequestCode)

                if viewModel.remainingSeconds > 0 {
                    Text("email_binding_resend_after")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    Text(verbatim: viewModel.formattedTimer)
                        .font(.headline.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                VerificationCodeInputView(
                    code: Binding(
                        get: { viewModel.code },
                        set: { viewModel.updateCode($0) }
                    ),
                    isFocused: $isCodeInputFocused,
                    isError: viewModel.status == .invalidCode,
                )

                Button(action: {
                    viewModel.confirmCode { email in
                        onSuccess(email)
                    }
                }) {
                    if viewModel.isConfirmingCode {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Text("profile_edit_bind_email_confirm")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canConfirm)

                switch viewModel.status {
                case .idle:
                    EmptyView()
                case .success:
                    Text("profile_edit_bind_email_success")
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                case .invalidEmail:
                    InlineErrorView(key: "email_error_invalid")
                case .alreadyUsed:
                    InlineErrorView(key: "email_binding_error_used")
                case .invalidCode:
                    InlineErrorView(key: "email_error_invalid_code")
                case .unauthorized:
                    InlineErrorView(key: "email_error_unauthorized")
                case .networkError:
                    InlineErrorView(key: "profile_edit_bind_email_error")
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("profile_edit_bind_email_sheet_title")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.cancelTasks()
        }
    }
}
