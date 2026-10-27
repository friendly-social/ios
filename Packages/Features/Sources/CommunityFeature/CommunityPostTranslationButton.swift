import Foundation
import PostTranslationService
import SwiftUI

struct CommunityPostTranslationButton: View {
  let model: CommunityPostTranslationViewModel
  var alignment: Alignment = .leading

  var body: some View { contentView() }
}

private extension CommunityPostTranslationButton {
  private func contentView() -> some View {
    Menu { menuContent() } label: { labelView() } primaryAction: {
      Task { await model.cycleLanguage() }
    }
    .menuIndicator(.hidden)
    .buttonStyle(.plain)
    .disabled(model.requestID != nil)
    .accessibilityLabel(actionLabel)
    .accessibilityValue(Text(verbatim: model.languageLabel ?? ""))
    .accessibilityHint(.postTranslationMenuHint)
  }

  private func labelView() -> some View {
    Text(verbatim: model.languageLabel ?? "")
      .font(.subheadline.weight(.medium))
      .foregroundStyle(model.isTranslated ? Color.accentColor : Constants.foreground)
      .opacity(model.requestID == nil ? 1 : 0)
      .overlay {
        if model.requestID != nil { ProgressView().controlSize(.mini) }
      }
      .frame(minWidth: Constants.touchTarget, minHeight: Constants.touchTarget, alignment: alignment)
      .contentShape(.rect)
  }

  private func menuContent() -> some View {
    Group {
      Button(.postTranslationToRussian) { Task { await model.translate(to: .russian) } }
      Button(.postTranslationToEnglish) { Task { await model.translate(to: .english) } }
      if model.isTranslated {
        Divider()
        Button(.postTranslationShowOriginal) { Task { await model.showOriginal() } }
      }
    }
  }

  private var actionLabel: LocalizedStringResource {
    switch model.nextSelection {
    case .original: .postTranslationShowOriginal
    case .translated(.english): .postTranslationToEnglish
    case .translated(.russian): .postTranslationToRussian
    }
  }
}

private enum Constants {
  static let foreground = Color.secondary
  static let touchTarget: CGFloat = 44
}
