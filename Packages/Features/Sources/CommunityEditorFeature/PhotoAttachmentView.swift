import SwiftNavigation
import UIKit

final class PhotoAttachmentView: UIView {
  private let presentation: PhotoAttachmentPresentation
  private let imageView = UIImageView()
  private let loading = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let retry = UIButton(type: .system)
  private var observation: ObserveToken?

  init(presentation: PhotoAttachmentPresentation, alt: String, size: CGSize) {
    self.presentation = presentation
    super.init(frame: CGRect(origin: .zero, size: size))
    configureImage(alt: alt)
    configureLoading()
    configureRetry()
    constrainViews()
    observation = observe { [weak self] in self?.render() }
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let hit = super.hitTest(point, with: event), hit.isDescendant(of: retry) else { return nil }
    return hit
  }
}

private extension PhotoAttachmentView {
  private func configureImage(alt: String) {
    imageView.contentMode = .scaleAspectFit
    imageView.isAccessibilityElement = true
    imageView.accessibilityIdentifier = "community.editorPhoto"
    imageView.accessibilityLabel = alt.isEmpty ? String(localized: .editorPhoto) : alt
    addSubview(imageView)
  }

  private func configureLoading() {
    loading.clipsToBounds = true
    loading.layer.cornerRadius = PhotoAttachment.minimumInteractiveHeight / 2
    spinner.isAccessibilityElement = true
    spinner.accessibilityIdentifier = "community.photoUploading"
    spinner.accessibilityLabel = String(localized: .editorPhotosUploading)
    addSubview(loading)
    loading.contentView.addSubview(spinner)
  }

  private func configureRetry() {
    var configuration = UIButton.Configuration.glass()
    configuration.image = UIImage(systemName: Constants.retrySymbol)
    retry.configuration = configuration
    retry.accessibilityIdentifier = "community.retryPhoto"
    retry.accessibilityLabel = String(localized: .editorPhotosRetry)
    retry.accessibilityHint = String(localized: .editorPhotosFailed)
    retry.addAction(UIAction { [weak presentation] _ in presentation?.retry?() }, for: .touchUpInside)
    addSubview(retry)
  }

  private func constrainViews() {
    [imageView, loading, spinner, retry].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
      spinner.centerXAnchor.constraint(equalTo: loading.contentView.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: loading.contentView.centerYAnchor),
    ])
    constrainBadge(loading)
    constrainBadge(retry)
  }

  private func constrainBadge(_ badge: UIView) {
    NSLayoutConstraint.activate([
      badge.centerXAnchor.constraint(equalTo: centerXAnchor),
      badge.centerYAnchor.constraint(equalTo: centerYAnchor),
      badge.widthAnchor.constraint(equalToConstant: PhotoAttachment.minimumInteractiveHeight),
      badge.heightAnchor.constraint(equalToConstant: PhotoAttachment.minimumInteractiveHeight),
    ])
  }

  private func render() {
    imageView.image = presentation.image
    let uploading = presentation.state == .preparing || presentation.state == .uploading
    loading.isHidden = !uploading
    if uploading { spinner.startAnimating() } else { spinner.stopAnimating() }
    retry.isHidden = presentation.state != .failed
  }
}

private enum Constants {
  static let retrySymbol = "arrow.clockwise"
}
