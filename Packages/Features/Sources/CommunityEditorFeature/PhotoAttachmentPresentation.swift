import Observation
import UIKit

@MainActor @Observable
final class PhotoAttachmentPresentation {
  var image: UIImage?
  var state: EditorPhotoUploads.State?
  @ObservationIgnored var retry: (() -> Void)?

  init(image: UIImage? = nil) { self.image = image }
}
