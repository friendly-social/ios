import UIKit

final class PhotoAttachmentViewProvider: NSTextAttachmentViewProvider {
  override func loadView() {
    // UIKit creates attachment views on the main thread. Remove the bridge when its hook is actor annotated.
    nonisolated(unsafe) let photo = textAttachment as? PhotoAttachment
    let size = photo?.displayBounds(in: textLayoutManager?.textContainer).size ?? .zero
    view = MainActor.assumeIsolated {
      guard let photo else { return nil }
      return PhotoAttachmentView(presentation: photo.presentation, alt: photo.alt, size: size)
    }
  }

  override func attachmentBounds(
    for attributes: [NSAttributedString.Key: Any], location: any NSTextLocation,
    textContainer: NSTextContainer?, proposedLineFragment: CGRect, position: CGPoint
  ) -> CGRect {
    guard let photo = textAttachment as? PhotoAttachment else { return .zero }
    return photo.displayBounds(in: textContainer)
  }
}
