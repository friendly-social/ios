import Foundation
import UIKit

struct PhotoFragment: Codable {
  static var typeIdentifier: String { Constants.typeIdentifier }
  static var maximumEncodedBytes: Int { Constants.maximumEncodedBytes }

  private let version: Int
  private let runs: [Run]
  private var previews: [UUID: Data]?

  @MainActor init(_ text: NSAttributedString) {
    version = Constants.version
    var previewValues: [UUID: Data] = [:]
    var values: [Run] = []
    EditorTextRuns.enumerate(text) { attributes, range in
      let photo = attributes[.attachment] as? PhotoAttachment
      if let photo, photo.hasLoadedPreview, previewValues[photo.sourceID] == nil {
        previewValues[photo.sourceID] = photo.image.flatMap(PhotoImagePreview.bounded)?.pngData()
      }
      values.append(Run(
        text: (text.string as NSString).substring(with: range),
        format: EditorTextAttributes.formatBits(in: attributes),
        link: EditorLink.url(from: attributes[.link])?.absoluteString,
        photo: photo.map(Photo.init)))
    }
    runs = values
    previews = previewValues
  }

  @MainActor func encodedData(maximumBytes: Int) -> Data? {
    var fragment = self
    var maximumPixels = PhotoImagePreview.maximumPixels
    while let data = try? JSONEncoder().encode(fragment) {
      if data.count <= maximumBytes { return data }
      guard fragment.previews?.isEmpty == false else { return nil }
      maximumPixels /= 2
      fragment.previews = maximumPixels >= Constants.minimumPreviewPixels
        ? fragment.reducedPreviews(maximumPixels: maximumPixels) : nil
    }
    return nil
  }

  @MainActor func attributedText(maximumDecodedBytes: Int = Constants.maximumDecodedBytes) -> NSAttributedString? {
    guard Constants.supportedVersions.contains(version) else { return nil }
    let sources = Set(runs.compactMap { $0.photo?.sourceID })
    let imageBudget = maximumDecodedBytes / max(1, sources.count)
    guard imageBudget >= Constants.minimumImageBytes else { return nil }
    let pixelLimit = min(PhotoImagePreview.maximumPixels, Int(sqrt(Double(imageBudget / 4))))
    let result = NSMutableAttributedString(string: "")
    var images: [UUID: (image: UIImage, loaded: Bool)] = [:]
    for run in runs {
      if let metadata = run.photo {
        let preview = images[metadata.sourceID] ?? resolvedPreview(for: metadata, pixels: pixelLimit, bytes: imageBudget)
        images[metadata.sourceID] = preview
        guard run.text == Constants.attachment,
              let photo = metadata.attachment(image: preview.image, loaded: preview.loaded) else { return nil }
        result.append(NSAttributedString(attachment: photo))
      } else {
        var attributes = EditorTextAttributes.make(formatBits: run.format)
        attributes[.link] = EditorLink.url(from: run.link)
        result.append(NSAttributedString(string: run.text, attributes: attributes))
      }
    }
    return result
  }
}

private extension PhotoFragment {
  @MainActor private func resolvedPreview(for photo: Photo, pixels: Int, bytes: Int) -> (image: UIImage, loaded: Bool) {
    let data = previews?[photo.sourceID] ?? photo.preview
    var maximumPixels = pixels
    while maximumPixels > 1 {
      let decoded = data.flatMap { PhotoImagePreview.decode($0, maximumPixels: maximumPixels) }
      let image = decoded ?? PhotoImagePreview.placeholder(maximumPixels: maximumPixels)
      if let bitmap = image.cgImage, bitmap.bytesPerRow * bitmap.height <= bytes { return (image, decoded != nil) }
      maximumPixels /= 2
    }
    return (PhotoImagePreview.placeholder(maximumPixels: 1), false)
  }

  @MainActor private func reducedPreviews(maximumPixels: Int) -> [UUID: Data] {
    (previews ?? [:]).compactMapValues { data in
      PhotoImagePreview.decode(data, maximumPixels: maximumPixels)?.pngData()
    }
  }

  private struct Run: Codable {
    let text: String
    let format: Int
    let link: String?
    let photo: Photo?
  }

  private struct Photo: Codable {
    let id: UUID
    let sourceID: UUID
    let sourceURL: URL
    let ready: Bool
    let alt: String?
    let preview: Data?

    @MainActor init(_ photo: PhotoAttachment) {
      id = photo.id
      sourceID = photo.sourceID
      sourceURL = photo.sourceURL
      ready = photo.ready
      alt = photo.alt
      preview = nil
    }

    @MainActor func attachment(image: UIImage, loaded: Bool) -> PhotoAttachment? {
      guard PhotoAttachment.isValidSource(sourceURL),
        PhotoAttachment.localID(sourceURL).map({ $0 == sourceID }) ?? true else { return nil }
      let photo = PhotoAttachment(id: id, sourceID: sourceID, sourceURL: sourceURL, preview: image)
      photo.ready = ready && EditorLink.url(from: sourceURL) != nil
      photo.hasLoadedPreview = loaded
      photo.alt = alt ?? ""
      return photo
    }
  }
}

private enum Constants {
  static let typeIdentifier = "ly.getfriend.editor.fragment.v1"
  static let maximumEncodedBytes = 8 * 1024 * 1024
  static let maximumDecodedBytes = 32 * 1024 * 1024
  static let minimumImageBytes = 64
  static let version = 2
  static let supportedVersions = [1, 2]
  static let minimumPreviewPixels = 32
  static let attachment = "\u{fffc}"
}
