import SwiftUI

struct VerificationCodeInputView: View {
  @Binding var code: String
  @FocusState.Binding var isFocused: Bool
  var isError = false

  var body: some View {
    codeCellsView
      .accessibilityHidden(true)
      .overlay { codeTextField }
  }
}

private extension VerificationCodeInputView {
  private var digits: [String] {
    Array(code.filter(\.isNumber).prefix(8)).map(String.init)
  }

  private var codeCellsView: some View {
    HStack(spacing: Constants.cellSpacing) {
      leadingCodeCells
      codeSeparatorLabel
      trailingCodeCells
    }
    .frame(maxWidth: .infinity)
  }

  private var leadingCodeCells: some View {
    ForEach(0..<4, id: \.self) { index in
      codeCell(at: index)
    }
  }

  private var codeSeparatorLabel: some View {
    Text(verbatim: "-")
      .font(.headline)
      .foregroundStyle(.secondary)
      .frame(width: Constants.separatorWidth)
  }

  private var trailingCodeCells: some View {
    ForEach(4..<8, id: \.self) { index in
      codeCell(at: index)
    }
  }

  private var codeTextField: some View {
    TextField(text: $code) { Text(verbatim: "") }
      .accessibilityLabel(Text(.profileEditBindEmailCodePlaceholder))
      .textFieldStyle(.plain)
      .keyboardType(.numberPad)
      .textContentType(.oneTimeCode)
      .focused($isFocused)
      .foregroundStyle(.clear)
      .tint(.clear)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(.rect)
  }

  private func codeCell(at index: Int) -> some View {
    VerificationCodeCell(
      digit: digit(at: index),
      isFocused: isFocused && index == digits.count,
      isError: isError
    )
  }

  private func digit(at index: Int) -> String {
    guard index < digits.count else { return "" }
    return digits[index]
  }
}

private struct VerificationCodeCell: View {
  let digit: String
  let isFocused: Bool
  let isError: Bool

  var body: some View {
    Text(digit)
      .font(.title3.monospacedDigit())
      .frame(maxWidth: .infinity, minHeight: Constants.cellHeight)
      .background(Constants.cellBackground)
      .clipShape(RoundedRectangle(cornerRadius: Constants.cellRadius))
      .overlay {
        RoundedRectangle(cornerRadius: Constants.cellRadius)
          .stroke(
            isError ? Color.red : Color.accentColor.opacity(isFocused ? 1 : Constants.inactiveBorderOpacity),
            lineWidth: isFocused ? Constants.focusedBorderWidth : Constants.borderWidth
          )
      }
  }
}

private enum Constants {
  static let cellBackground = Color(uiColor: .secondarySystemGroupedBackground)
  static let cellHeight: CGFloat = 52
  static let cellRadius: CGFloat = 10
  static let cellSpacing: CGFloat = 4
  static let separatorWidth: CGFloat = 12
  static let borderWidth: CGFloat = 1
  static let focusedBorderWidth: CGFloat = 2
  static let inactiveBorderOpacity = 0.35
}
