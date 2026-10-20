import Foundation
import UIKit

@MainActor
final class PhotoAttachment: NSTextAttachment {
  override class var supportsSecureCoding: Bool { true }
  let id: UUID
  let sourceID: UUID
  var sourceURL: URL
  var ready = false
  var alt = ""
  var hasLoadedPreview = false
  lazy var presentation = PhotoAttachmentPresentation(image: image)
  override var usesTextAttachmentView: Bool { true }

  nonisolated static func isLocalSource(_ url: URL) -> Bool {
    url.scheme?.lowercased() == Constants.localScheme
  }

  nonisolated static func localID(_ url: URL) -> UUID? {
    guard isLocalSource(url), let host = url.host else { return nil }
    return UUID(uuidString: host)
  }

  nonisolated static func isValidSource(_ url: URL) -> Bool {
    EditorLink.url(from: url) != nil || localID(url) != nil
  }

  init(id: UUID, sourceID: UUID? = nil, sourceURL: URL? = nil, preview: UIImage? = nil) {
    self.id = id
    self.sourceID = sourceID ?? id
    self.sourceURL = sourceURL ?? Self.localURL(sourceID ?? id)
    hasLoadedPreview = preview != nil
    let image = preview ?? PhotoImagePreview.placeholder()
    super.init(data: nil, ofType: nil)
    setPreview(image)
    allowsTextAttachmentView = true
  }

  override init(data: Data?, ofType uti: String?) {
    id = UUID()
    sourceID = id
    sourceURL = Self.localURL(id)
    super.init(data: data, ofType: uti)
    allowsTextAttachmentView = true
  }

  required init?(coder: NSCoder) {
    id = UUID()
    sourceID = id
    sourceURL = Self.localURL(id)
    super.init(coder: coder)
    bounds = .zero
    allowsTextAttachmentView = true
  }

  func setPreview(_ preview: UIImage) {
    image = preview
    presentation.image = preview
  }

  override func viewProvider(
    for parentView: UIView?, location: any NSTextLocation, textContainer: NSTextContainer?
  ) -> NSTextAttachmentViewProvider? {
    let provider = PhotoAttachmentViewProvider(textAttachment: self, parentView: parentView,
      textLayoutManager: textContainer?.textLayoutManager, location: location)
    provider.tracksTextAttachmentViewBounds = true
    return provider
  }

  nonisolated func displayBounds(in textContainer: NSTextContainer?) -> CGRect {
    let available = (textContainer?.size.width ?? Constants.maximumWidth) - 2 * (textContainer?.lineFragmentPadding ?? 0)
    let size = image?.size ?? .zero
    let ratio = size.height / max(size.width, 1)
    let width = min(Constants.maximumWidth, max(1, available), Constants.maximumHeight / max(ratio, Constants.minimumAspectRatio))
    return CGRect(x: 0, y: Constants.baselineOffset, width: max(width, Constants.minimumInteractiveHeight),
      height: max(width * ratio, Constants.minimumInteractiveHeight))
  }
}

extension PhotoAttachment {
  static var minimumInteractiveHeight: CGFloat { Constants.minimumInteractiveHeight }

  nonisolated static func localURL(_ id: UUID) -> URL {
    URL(string: "\(Constants.localScheme)://\(id.uuidString)")!
  }
}

private enum Constants {
  static let minimumInteractiveHeight: CGFloat = 44
  static let localScheme = "friendly-photo"
  static let minimumAspectRatio: CGFloat = 0.001
  static let maximumWidth: CGFloat = 280
  static let maximumHeight: CGFloat = 320
  static let baselineOffset: CGFloat = -8
}
