import SwiftUI

package struct EmailBindingView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dismiss) private var dismiss
  @FocusState private var isEmailFocused: Bool
  @FocusState private var isCodeFocused: Bool
  @ScaledMetric(relativeTo: .title) private var symbolSize = Constants.symbolSize
  @State private var model: EmailBindingViewModel
  private let onFinish: () -> Void

  package init(onLinked: @escaping (String) -> Void, onFinish: @escaping () -> Void) {
    _model = State(initialValue: EmailBindingViewModel(onLinked: onLinked))
    self.onFinish = onFinish
  }

  package var body: some View {
    ScrollView {
      VStack(spacing: Constants.sectionSpacing) {
        headerView()
        stepView()
      }
      .frame(maxWidth: Constants.contentWidth)
      .frame(maxWidth: .infinity)
      .padding(.horizontal)
      .padding(.vertical, Constants.sectionSpacing)
    }
    .scrollBounceBehavior(.basedOnSize)
    .scrollDismissesKeyboard(.interactively)
    .background(Constants.background)
    .navigationTitle(.profileEditBindEmailSheetTitle)
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: model.step) { _, step in stepChanged(step) }
    .onDisappear { model.cancelOperation() }
  }
}

private extension EmailBindingView {
  private func headerView() -> some View {
    VStack(spacing: Constants.spacing) {
      headerSymbol()
      Text(stepTitle).font(.title2.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      switch model.step {
      case .address: headerHint(.emailBindingAddressHint)
      case let .code(email): recipientView(email)
      case .success: headerHint(.emailBindingLinkedHint)
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }

  private func headerHint(_ title: LocalizedStringResource) -> some View {
    Text(title)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }

  private func headerSymbol() -> some View {
    ZStack(alignment: .bottomTrailing) {
      Image(systemName: isLinked ? Constants.successSymbol : Constants.emailSymbol)
        .font(.title)
        .foregroundStyle(isLinked ? Color.green : Color.accentColor)
        .contentTransition(.symbolEffect(.replace))
      if case .code = model.step {
        Image(systemName: Constants.successSymbol)
          .font(.footnote)
          .foregroundStyle(Color.accentColor)
          .background(Constants.surface, in: .circle)
          .offset(x: Constants.badgeInset, y: Constants.badgeInset)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(width: symbolSize, height: symbolSize)
    .background(Constants.surface, in: .rect(cornerRadius: Constants.symbolRadius))
    .animation(reduceMotion ? nil : .easeInOut(duration: Constants.transitionDuration), value: model.step)
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func stepView() -> some View {
    switch model.step {
    case .address: addressStepView()
    case .code: codeStepView()
    case .success: primaryButton(.emailBindingBackToProfile, action: onFinish)
    }
  }

  private func addressStepView() -> some View {
    VStack(alignment: .leading, spacing: Constants.spacing) {
      addressField()
      errorView()
      if model.failure == .unauthorized { closeBindingButton() }
      else { submitButton(.profileEditBindEmailSendCode, progress: .emailBindingSending) }
    }
  }

  private func addressField() -> some View {
    TextField(
      .profileEditBindEmailEmailPlaceholder,
      text: Binding(get: { model.email }, set: model.updateEmail),
      prompt: Text(.profileEditBindEmailEmailPlaceholder).foregroundStyle(.secondary)
    )
    .keyboardType(.emailAddress)
    .textContentType(.emailAddress)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .focused($isEmailFocused)
    .submitLabel(.continue)
    .onSubmit { model.submit() }
    .disabled(model.isWorking || model.failure == .unauthorized)
    .padding(Constants.fieldPadding)
    .background(Constants.surface, in: .rect(cornerRadius: Constants.fieldRadius))
  }

  private func codeStepView() -> some View {
    VStack(alignment: .leading, spacing: Constants.spacing) {
      Text(.emailBindingCodeLabel).font(.subheadline.weight(.semibold))
      VerificationCodeInputView(
        code: Binding(get: { model.code }, set: model.updateCode),
        isFocused: $isCodeFocused,
        isError: model.failure == .invalidCode || model.failure == .invalidCodeFormat
      )
      .disabled(model.isWorking || model.failure == .unauthorized)
      errorView()
      if model.failure == .unauthorized {
        closeBindingButton()
      } else {
        submitButton(.profileEditBindEmailConfirm, progress: .emailBindingChecking)
        codeHintsView()
      }
    }
  }

  private func recipientView(_ email: String) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Constants.spacing) {
        Text(verbatim: email).fontWeight(.semibold).fixedSize()
        changeAddressButton()
      }
      VStack(spacing: Constants.spacing) {
        Text(verbatim: email).fontWeight(.semibold)
        changeAddressButton()
      }
    }
    .font(.subheadline)
  }

  private func changeAddressButton() -> some View {
    Button(.emailBindingChangeAddress, action: model.changeEmail)
      .frame(minHeight: Constants.minimumTapHeight)
      .disabled(model.isWorking || model.failure == .unauthorized)
  }

  private func codeHintsView() -> some View {
    VStack(spacing: Constants.captionSpacing) {
      Text(.emailBindingMissingMail)
      Text(.emailBindingCodeDuration)
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func errorView() -> some View {
    if let failure = model.failure {
      Text(message(for: failure))
        .font(.footnote)
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func submitButton(
    _ title: LocalizedStringResource,
    progress: LocalizedStringResource
  ) -> some View {
    primaryButton(
      model.failure == .requestFailed ? .emailBindingRetry : title,
      progress: model.isWorking ? progress : nil,
      isEnabled: model.canSubmit
    ) { model.submit() }
  }

  private func closeBindingButton() -> some View {
    primaryButton(.emailBindingClose) { dismiss() }
  }

  private func primaryButton(
    _ title: LocalizedStringResource,
    progress: LocalizedStringResource? = nil,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: Constants.spacing) {
        if progress != nil { ProgressView().tint(.white).accessibilityHidden(true) }
        Text(progress ?? title)
      }
    }
    .buttonStyle(EmailBindingPrimaryButtonStyle(isWorking: progress != nil))
    .disabled(!isEnabled)
  }

  private func stepChanged(_ step: EmailBindingViewModel.Step) {
    isEmailFocused = false
    isCodeFocused = false
    switch step {
    case .address: isEmailFocused = true
    case .code: isCodeFocused = true
    case .success: break
    }
  }

  private var isLinked: Bool {
    if case .success = model.step { return true }
    return false
  }

  private var stepTitle: LocalizedStringResource {
    switch model.step {
    case .address: .emailBindingAddressTitle
    case .code: .emailBindingCodeTitle
    case .success: .emailBindingLinked
    }
  }

  private func message(for failure: EmailBindingViewModel.Failure) -> LocalizedStringResource {
    switch failure {
    case .addressUnavailable: .emailBindingErrorUsed
    case .invalidCodeFormat: .emailBindingCodeFormat
    case .invalidCode: .emailBindingCodeRejected
    case .unauthorized: .emailBindingSessionInvalid
    case .requestFailed:
      if case .address = model.step { .emailBindingRequestFailed }
      else { .emailBindingVerificationFailed }
    }
  }
}

private struct EmailBindingPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @ScaledMetric(relativeTo: .body) private var height = Constants.primaryButtonHeight
  let isWorking: Bool

  func makeBody(configuration: Configuration) -> some View {
    let isHighlighted = isEnabled || isWorking
    let tint = isHighlighted ? Constants.primaryButtonTint : Constants.inactiveButtonTint
    configuration.label
      .font(.headline)
      .foregroundStyle(isHighlighted ? Color.white : Color.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, Constants.fieldPadding)
      .frame(maxWidth: .infinity, minHeight: height)
      .contentShape(.capsule)
      .glassEffect(.regular.tint(tint).interactive(isEnabled), in: .capsule)
  }
}

private enum Constants {
  static let background = Color(uiColor: .systemGroupedBackground)
  static let surface = Color(uiColor: .secondarySystemGroupedBackground)
  static let emailSymbol = "envelope"
  static let successSymbol = "checkmark.circle.fill"
  static let spacing: CGFloat = 8
  static let captionSpacing: CGFloat = 6
  static let sectionSpacing: CGFloat = 24
  static let fieldPadding: CGFloat = 14
  static let fieldRadius: CGFloat = 16
  static let symbolSize: CGFloat = 64
  static let symbolRadius: CGFloat = 22
  static let badgeInset: CGFloat = 4
  static let contentWidth: CGFloat = 420
  static let minimumTapHeight: CGFloat = 44
  static let primaryButtonHeight: CGFloat = 52
  static let primaryButtonTint = Color(uiColor: .systemBlue)
  static let inactiveButtonTint = Color(uiColor: .secondarySystemFill)
  static let transitionDuration = 0.24
}
