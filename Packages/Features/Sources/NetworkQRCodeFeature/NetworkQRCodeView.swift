import SwiftUI
import UIKit

public struct NetworkQRCodeView: View {
  @State private var model: NetworkQRCodeViewModel

  public init(onDismiss: @escaping () -> Void) {
    _model = State(initialValue: .init(onDismiss: onDismiss))
  }

  public var body: some View {
    NavigationStack {
      contentView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(.networkQrcodeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton() }
        .alert(.networkQrcodeReplaceTitle, isPresented: $model.confirmsReplacement) {
          Button(.networkQrcodeReplaceAction, role: .destructive) {
            Task { await model.replaceCode() }
          }
          Button(.networkQrcodeCancel, role: .cancel) {}
        } message: {
          Text(.networkQrcodeReplaceMessage)
        }
    }
    .task { await model.start() }
    .task(id: model.refreshDeadline) { [deadline = model.refreshDeadline] in
      await model.refreshAtExpiry(deadline)
    }
  }
}

private extension NetworkQRCodeView {
  @ViewBuilder
  private func contentView() -> some View {
    switch model.state {
    case .failed:
      ContentUnavailableView {
        Label(.ioErrorTitle, systemImage: Constants.connectionErrorIcon)
      } description: {
        Text(.ioErrorSubtitle)
      } actions: {
        Button(.networkQrcodeRetry) { Task { await model.retry() } }
          .buttonStyle(.glassProminent)
      }
    case .loading, .refreshing, .ready:
      invitationView()
    }
  }

  private func closeButton() -> some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button(action: model.onDismiss) {
        Label(.networkQrcodeClose, systemImage: Constants.closeIcon)
          .labelStyle(.iconOnly)
      }
    }
  }

  private func invitationView() -> some View {
    ScrollView {
      VStack(spacing: Constants.spacing) {
        headingView()
        invitationCode()
        Text(.networkQrcodeDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        shareButtons()
        noticeView()
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: Constants.contentWidth)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, Constants.horizontalInset)
      .padding(.vertical, Constants.verticalInset)
    }
    .scrollBounceBehavior(.basedOnSize)
  }

  private func headingView() -> some View {
    VStack(spacing: Constants.captionSpacing) {
      Text(.networkQrcodeHeading).font(.title2.weight(.semibold))
      Text(.networkQrcodeSubtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func invitationCode() -> some View {
    if let invitation = model.invitation {
      qrCodeView(invitation.image)
      expirationView(invitation.expiration)
    } else {
      loadingCode()
      Capsule()
        .fill(.quaternary)
        .frame(width: Constants.expirationPlaceholderWidth, height: Constants.expirationPlaceholderHeight)
        .accessibilityHidden(true)
    }
  }

  private func loadingCode() -> some View {
    Image(Constants.loadingCodeAsset, bundle: .module)
      .resizable()
      .scaledToFit()
      .opacity(Constants.placeholderOpacity)
      .blur(radius: Constants.placeholderBlur)
      .frame(maxWidth: Constants.codeWidth)
      .background(.white)
      .accessibilityHidden(true)
      .clipShape(.rect(cornerRadius: Constants.codeCornerRadius))
      .overlay {
        ProgressView()
          .tint(.black)
          .padding(.horizontal, Constants.progressHorizontalInset)
          .padding(.vertical, Constants.progressVerticalInset)
          .glassEffect(in: .capsule)
      }
  }

  private func qrCodeView(_ image: UIImage) -> some View {
    Image(uiImage: image)
      .resizable()
      .interpolation(.none)
      .scaledToFit()
      .frame(maxWidth: Constants.codeWidth)
      .clipShape(.rect(cornerRadius: Constants.codeCornerRadius))
      .accessibilityLabel(Text(.networkQrcodeImage))
  }

  private func expirationView(_ expiration: Date) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        inlineCountdown(expiration)
        replaceButton()
          .fixedSize(horizontal: true, vertical: false)
      }
      VStack {
        ViewThatFits(in: .horizontal) {
          inlineCountdown(expiration)
          VStack {
            countdownLabel()
            countdownValue(expiration)
          }
        }
        replaceButton()
      }
    }
    .font(.subheadline)
  }

  private func inlineCountdown(_ expiration: Date) -> some View {
    HStack {
      countdownLabel()
      countdownValue(expiration)
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private func countdownLabel() -> some View {
    Label(.networkQrcodeRemaining, systemImage: Constants.clockIcon)
  }

  private func countdownValue(_ expiration: Date) -> some View {
    Text(timerInterval: Date.distantPast...expiration, countsDown: true)
      .monospacedDigit()
  }

  private func replaceButton() -> some View {
    Button(.networkQrcodeRefresh, action: model.requestReplacement)
  }

  private func shareButtons() -> some View {
    VStack(spacing: Constants.actionSpacing) {
      shareButton()
      ViewThatFits {
        HStack(spacing: Constants.actionSpacing) {
          copyButton()
          saveButton()
        }
        VStack(spacing: Constants.actionSpacing) {
          copyButton()
          saveButton()
        }
      }
      .buttonStyle(.glass)
    }
    .controlSize(.large)
    .disabled(model.activeInvitation == nil)
  }

  private func shareButton() -> some View {
    Group {
      if let invitation = model.activeInvitation {
        ShareLink(item: invitation.url) { shareLabel() }
      } else {
        Button(action: {}) { shareLabel() }
      }
    }
    .buttonStyle(.glassProminent)
  }

  private func shareLabel() -> some View {
    Label(.networkQrcodeShare, systemImage: Constants.shareIcon)
      .frame(maxWidth: .infinity)
  }

  private func copyButton() -> some View {
    Button {
      Task { await model.copyLink() }
    } label: {
      Label(.networkQrcodeCopy, systemImage: Constants.copyIcon)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
    }
  }

  private func saveButton() -> some View {
    Button {
      Task { await model.saveImage() }
    } label: {
      Label(.networkQrcodeSave, systemImage: Constants.qrIcon)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
    }
  }

  @ViewBuilder
  private func noticeView() -> some View {
    if let notice = model.notice {
      Text(notice.title)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

}

private extension NetworkQRCodeViewModel.Notice {
  var title: LocalizedStringResource {
    switch self {
    case .linkCopied: .networkQrcodeCopied
    case .imageSaved: .networkQrcodeSaved
    case .saveFailed: .networkQrcodeSaveFailed
    }
  }
}

private enum Constants {
  static let spacing: CGFloat = 20
  static let actionSpacing: CGFloat = 10
  static let horizontalInset: CGFloat = 24
  static let verticalInset: CGFloat = 22
  static let captionSpacing: CGFloat = 4
  static let codeWidth: CGFloat = 208
  static let codeCornerRadius: CGFloat = 20
  static let loadingCodeAsset = "LoadingInvitationCode"
  static let placeholderOpacity = 0.48
  static let placeholderBlur: CGFloat = 6
  static let progressHorizontalInset: CGFloat = 22
  static let progressVerticalInset: CGFloat = 12
  static let expirationPlaceholderWidth: CGFloat = 114
  static let expirationPlaceholderHeight: CGFloat = 19
  static let contentWidth: CGFloat = 440
  static let closeIcon = "xmark"
  static let connectionErrorIcon = "wifi.slash"
  static let clockIcon = "clock"
  static let shareIcon = "square.and.arrow.up"
  static let copyIcon = "doc.on.doc"
  static let qrIcon = "qrcode"
}
