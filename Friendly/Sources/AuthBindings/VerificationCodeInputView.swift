import SwiftUI

struct VerificationCodeInputView: View {
    @Binding var code: String
    @FocusState.Binding var isFocused: Bool
    var isError: Bool = false

    private var digits: [String] {
        Array(code.filter(\.isNumber).prefix(8)).map(String.init)
    }

    var body: some View {
        ZStack {
            codeCellsView
            hiddenCodeTextField
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .frame(maxWidth: .infinity)
    }

    private var codeCellsView: some View {
        HStack(spacing: 4) {
            leadingCodeCells
            codeSeparatorLabel
            trailingCodeCells
        }
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
            .frame(width: 12)
    }

    private var trailingCodeCells: some View {
        ForEach(4..<8, id: \.self) { index in
            codeCell(at: index)
        }
    }

    private var hiddenCodeTextField: some View {
        TextField("", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($isFocused)
            .opacity(0.01)
            .frame(width: 1, height: 1)
    }

    private func codeCell(at index: Int) -> some View {
        VerificationCodeCell(
            digit: digit(at: index),
            isFocused: isFocused && index == digits.count,
            isError: isError,
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
            .frame(maxWidth: 36, minHeight: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isError
                            ? Color.red
                            : Color.accentColor.opacity(isFocused ? 1 : 0.35),
                        lineWidth: isFocused ? 2 : 1,
                    )
            }
    }
}
