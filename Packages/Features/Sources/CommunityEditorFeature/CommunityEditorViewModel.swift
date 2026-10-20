import CommunityProfileService
import Dependencies
import Foundation
import Observation
import PhotosUI
import Sharing
import SwiftNavigation
import SwiftUI
import UIKit

@MainActor @Observable
public final class CommunityEditorViewModel {
  public typealias Format = EditorTextFormat
  public enum FormatState { case on, off, mixed }
  enum PhotoPosition { case start, afterParagraph, end }
  struct LinkEdit {
    let range: NSRange
    let originalURL: URL?
    let title: String
  }

  public private(set) var markdown: String
  public private(set) var text = NSAttributedString(string: "")
  public private(set) var selection = NSRange(location: 0, length: 0)
  public private(set) var canUndo = false
  public private(set) var canRedo = false
  public private(set) var selectedPhotoID: UUID?
  public private(set) var isImporting = false
  public private(set) var photoError: LocalizedStringResource?
  var linkAddress = "https://"
  private(set) var linkEdit: LinkEdit?
  @ObservationIgnored @Dependency(EditorPhotoService.self) private var photoService
  @ObservationIgnored private let uploads = EditorPhotoUploads()
  @ObservationIgnored private var uploadObservation: ObserveToken?
  @ObservationIgnored private var session: CommunitySession?
  @ObservationIgnored private weak var textView: PhotoTextArea?
  @ObservationIgnored private var assets: [ObjectIdentifier: PhotoReference] = [:]
  @ObservationIgnored private var previewLoads: [URL: Task<Void, Never>] = [:]
  @ObservationIgnored private var isEditing = false
  private var hasUnfinishedPhotos = false
  private var selectionVersion = 0
  private var loadedSourceOnly: Bool?
  @ObservationIgnored private let fallbackHistory = UndoManager()
  @ObservationIgnored private var typingAttributes = EditorTextAttributes.make(formatBits: 0)
  var history: UndoManager { textView?.systemUndoManager ?? fallbackHistory }

  public init(source: String = "") { markdown = source }

  deinit { previewLoads.values.forEach { $0.cancel() } }

  public var sourceOnly: Bool {
    loadedSourceOnly ?? PhotoMarkdownCodec.requiresSourceEditing(markdown)
  }
  public var utf16Count: Int { markdown.utf16.count }
  var characterLimit: Int { Constants.characterLimit }
  public var canPublish: Bool {
    guard !isImporting, !hasUnfinishedPhotos else { return false }
    let value = markdown
    if loadedSourceOnly == false { return Self.isValidPostText(value) }
    return Self.isPublishable(value)
  }

  public static func isPublishable(_ source: String) -> Bool {
    isValidPostText(source) && !PhotoMarkdownCodec.containsPendingPhotos(source)
  }

  var canInsertPhoto: Bool { session != nil && !isImporting && !sourceOnly }
  var canSaveLink: Bool { EditorLink.url(from: linkAddress.trimmingCharacters(in: .whitespacesAndNewlines)) != nil }
  var isLinkSelected: Bool {
    _ = selectionVersion
    return selectedLink != nil
  }

  public func start(session: CommunitySession) {
    self.session = session
    ensureLoaded()
    restorePhotos()
  }

  public func loadSource(_ value: String) {
    cancelLinkEditing()
    if loadedSourceOnly == false, value == markdown { return }
    text = decodeSource(value)
    loadedSourceOnly = PhotoMarkdownCodec.requiresSourceEditing(value)
    markdown = value
    selection = NSRange(location: 0, length: 0)
    history.removeAllActions()
    synchronizeView()
    restorePhotos()
    updateStatus()
  }

  public func restoreCursor(_ position: Int?) {
    ensureLoaded()
    guard !sourceOnly else { return }
    let offset = position ?? text.length
    let valid = (0...text.length).contains(offset) && (offset == text.length
      || (text.string as NSString).rangeOfComposedCharacterSequence(at: offset).location == offset)
    setSelection(NSRange(location: valid ? offset : text.length, length: 0))
    textView?.revealSelection()
  }

  public func prepareForSaving() async throws { try await uploads.prepareForSaving() }

  func attach(_ view: PhotoTextArea) {
    ensureLoaded()
    textView = view
    view.model = self
    view.photoClipboard.view = view
    view.photoClipboard.model = self
    view.pasteDelegate = view.photoClipboard
    synchronizeView()
    view.revealSelection()
    observeUploads()
    restorePhotos()
  }

  func detach() {
    cancelLinkEditing()
    history.removeAllActions()
    textView?.resignFirstResponder()
    textView = nil
    updateStatus()
  }

  func refresh() {
    guard !isEditing else { return }
    if let view = textView { text = NSAttributedString(attributedString: view.textStorage) }
    if loadedSourceOnly == false { markdown = PhotoMarkdownCodec.encode(text) }
    assets = assets.filter { $0.value.photo != nil }
    updateStatus()
  }

  func selectionChanged() {
    guard !isEditing, let view = textView else { return }
    selectionVersion += 1
    selection = view.selectedRange
    selectedPhotoID = nil
    if selection.length <= 1, selection.location < text.length {
      selectedPhotoID = (text.attribute(.attachment, at: selection.location, effectiveRange: nil) as? PhotoAttachment)?.id
    }
    if let link = selectedLink, selection.length == 0, selection.location == NSMaxRange(link.range) {
      view.typingAttributes.removeValue(forKey: .link)
    }
    updateHistoryStatus()
  }

  func setSelection(_ value: NSRange) {
    ensureLoaded()
    selection = value
    textView?.selectedRange = value
  }

  func resignFocus() { textView?.resignFirstResponder() }

  func prepareForModeChange() {
    resignFocus()
    history.removeAllActions()
    loadSource(markdown)
  }

  func updateFonts() {
    guard let view = textView else { return }
    isEditing = true
    history.disableUndoRegistration()
    EditorTextRuns.enumerate(text) { attributes, range in
      guard attributes[.attachment] == nil else { return }
      let bits = EditorTextAttributes.formatBits(in: attributes)
      if let font = EditorTextAttributes.make(formatBits: bits)[.font] {
        view.textStorage.addAttribute(.font, value: font, range: range)
      }
    }
    let bits = EditorTextAttributes.formatBits(in: view.typingAttributes)
    view.typingAttributes[.font] = EditorTextAttributes.make(formatBits: bits)[.font]
    text = NSAttributedString(attributedString: view.textStorage)
    history.enableUndoRegistration()
    isEditing = false
  }

  func undo() { history.undo(); refresh() }

  func redo() { history.redo(); refresh() }

  func state(for format: Format) -> FormatState {
    _ = selectionVersion
    ensureLoaded()
    if selection.length == 0 {
      let attributes = textView?.typingAttributes ?? typingAttributes
      return EditorTextAttributes.formatBits(in: attributes) & format.rawValue != 0 ? .on : .off
    }
    var values: [Bool] = []
    text.enumerateAttributes(in: selection) { attributes, _, _ in
      if attributes[.attachment] == nil { values.append(EditorTextAttributes.formatBits(in: attributes) & format.rawValue != 0) }
    }
    if !values.isEmpty && values.allSatisfy({ $0 }) { return .on }
    return values.contains(true) ? .mixed : .off
  }

  func toggle(_ format: Format) {
    ensureLoaded()
    if selection.length == 0 {
      var attributes = textView?.typingAttributes ?? typingAttributes
      let bits = EditorTextAttributes.formatBits(in: attributes) ^ format.rawValue
      attributes.merge(EditorTextAttributes.make(formatBits: bits)) { _, new in new }
      typingAttributes = attributes
      textView?.typingAttributes = attributes
      selectionVersion += 1
      return
    }
    let enable = state(for: format) != .on
    let snapshot = text
    edit { result in
      snapshot.enumerateAttributes(in: selection) { attributes, range, _ in
        guard attributes[.attachment] == nil else { return }
        let previous = EditorTextAttributes.formatBits(in: attributes)
        var updated = EditorTextAttributes.make(formatBits: enable ? previous | format.rawValue : previous & ~format.rawValue)
        updated[.link] = EditorLink.url(from: attributes[.link])
        result.setAttributes(updated, range: range)
      }
    }
  }

  func editLink() {
    ensureLoaded()
    if let link = selectedLink { beginLinkEditing(in: link.range, url: link.url) }
    else {
      linkAddress = "https://"
      let title = (text.string as NSString).substring(with: selection)
      linkEdit = .init(range: selection, originalURL: nil, title: title)
    }
  }

  func beginLinkEditing(in range: NSRange, url: URL) {
    guard valid(range) else { return }
    setSelection(range)
    linkAddress = url.absoluteString
    linkEdit = .init(range: range, originalURL: url, title: (text.string as NSString).substring(with: range))
  }

  func cancelLinkEditing() { linkEdit = nil }

  func saveLink(_ draft: LinkEdit) {
    guard let url = EditorLink.url(from: linkAddress.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
    updateLink(draft, url: url)
  }

  func removeLink(_ draft: LinkEdit) { updateLink(draft, url: nil) }

  func importPhotos(_ items: [PhotosPickerItem]) async {
    guard session != nil, !isImporting else { return }
    isImporting = true
    photoError = nil
    defer { isImporting = false }
    for item in items {
      do {
        try Task.checkCancellation()
        let data = try await photoService.selectionData(item)
        try Task.checkCancellation()
        try await importPhoto(data)
      } catch is CancellationError { return }
      catch {
        guard !Task.isCancelled else { return }
        photoError = .editorPhotoImportError
      }
    }
  }

  func importPhoto(_ data: Data) async throws {
    guard let session else { throw EditorPhotoError.unavailable }
    let id = UUID()
    let content = try await photoService.restore(id, data, session)
    guard !Task.isCancelled else { throw CancellationError() }
    let photo = PhotoAttachment(id: id, preview: PhotoImagePreview.decode(content.preview))
    if let url = content.uploadedURL { photo.sourceURL = url; photo.ready = true }
    insertPhoto(photo)
  }

  func insertPhoto(_ photo: PhotoAttachment) {
    ensureLoaded()
    let location = selection.location
    edit { result in
      let inserted = NSMutableAttributedString(string: "", attributes: EditorTextAttributes.make(formatBits: 0))
      if location > 0, (result.string as NSString).character(at: location - 1) != Constants.lineFeed {
        inserted.append(NSAttributedString(string: "\n", attributes: EditorTextAttributes.make(formatBits: 0)))
      }
      inserted.append(NSAttributedString(attachment: photo))
      inserted.append(NSAttributedString(string: "\n", attributes: EditorTextAttributes.make(formatBits: 0)))
      result.replaceCharacters(in: selection, with: inserted)
      selection = NSRange(location: location + inserted.length, length: 0)
      typingAttributes = EditorTextAttributes.make(formatBits: 0)
    }
    registerPastedPhoto(photo)
    textView?.becomeFirstResponder()
  }

  func registerPastedPhoto(_ photo: PhotoAttachment) {
    rememberPhoto(photo)
    if photo.ready {
      uploads.remember(photo.sourceID, url: photo.sourceURL)
      if textView != nil { loadPreview(photo) }
    } else if let session {
      uploads.start(photo.sourceID, fallback: photo.image?.pngData(), session: session, service: photoService)
    }
    observeUploads()
    applyUploadStates(uploads.states.wrappedValue)
  }

  func dismissPhotoError() { photoError = nil }

  func retryPhotos() {
    photoError = nil
    guard let session else { return }
    for photo in photos() {
      uploads.retry(photo.sourceID, fallback: photo.image?.pngData(), session: session, service: photoService)
    }
  }

  func photoIDs() -> [UUID] { photos().map(\.id) }

  func movePhoto(to destination: PhotoPosition) {
    guard let id = selectedPhotoID, let range = photoParagraph(id) else { return }
    let content = text.attributedSubstring(from: range)
    edit { result in
      result.deleteCharacters(in: range)
      let position: Int
      switch destination {
      case .start: position = 0
      case .afterParagraph:
        let caret = min(range.location, result.length)
        position = (result.string as NSString).paragraphRange(for: NSRange(location: caret, length: 0)).upperBound
      case .end: position = result.length
      }
      let moved = NSMutableAttributedString(attributedString: content)
      if position > 0, (result.string as NSString).character(at: position - 1) != Constants.lineFeed {
        moved.insert(NSAttributedString(string: "\n", attributes: EditorTextAttributes.make(formatBits: 0)), at: 0)
      }
      if !moved.string.hasSuffix("\n") { moved.append(NSAttributedString(string: "\n")) }
      result.insert(moved, at: position)
      selection = NSRange(location: position + moved.length, length: 0)
    }
    textView?.scrollRangeToVisible(selection)
  }

  func removePhoto() {
    guard let id = selectedPhotoID, let range = photoParagraph(id) else { return }
    edit { result in
      result.deleteCharacters(in: range)
      selection = NSRange(location: min(range.location, result.length), length: 0)
      selectedPhotoID = nil
    }
  }
}

private extension CommunityEditorViewModel {
  private func decodeSource(_ source: String) -> NSAttributedString {
    var previews = loadedPhotoPreviews()
    let service = photoService
    return PhotoMarkdownCodec.decode(source) { url in
      if let image = previews[url] { return image }
      guard let data = service.cachedPreview(url), let image = PhotoImagePreview.decode(data) else { return nil }
      previews[url] = image
      return image
    }
  }

  private func ensureLoaded() { if loadedSourceOnly == nil { loadSource(markdown) } }

  private func synchronizeView() {
    guard let view = textView else { return }
    isEditing = true
    view.attributedText = text
    view.selectedRange = selection
    view.typingAttributes = typingAttributes
    isEditing = false
  }

  private func edit(_ operation: (NSMutableAttributedString) -> Void) {
    history.beginUndoGrouping()
    registerSnapshot()
    history.disableUndoRegistration()
    let result = NSMutableAttributedString(attributedString: text)
    operation(result)
    text = NSAttributedString(attributedString: result)
    synchronizeView()
    history.enableUndoRegistration()
    history.endUndoGrouping()
    refresh()
  }

  private func registerSnapshot() {
    let snapshot = text
    let previousSelection = selection
    let attributes = textView?.typingAttributes ?? typingAttributes
    history.registerUndo(withTarget: self) { model in
      model.registerSnapshot()
      model.history.disableUndoRegistration()
      model.text = snapshot
      model.selection = previousSelection
      model.typingAttributes = attributes
      model.synchronizeView()
      model.history.enableUndoRegistration()
      model.refresh()
    }
  }

  private var selectedLink: (range: NSRange, url: URL)? {
    var selected: (NSRange, URL)?
    text.enumerateAttribute(.link, in: NSRange(location: 0, length: text.length)) { value, range, stop in
      guard let url = EditorLink.url(from: value) else { return }
      let matches = selection.length == 0
        ? range.location <= selection.location && selection.location <= NSMaxRange(range)
        : NSIntersectionRange(range, selection).length > 0
      guard matches else { return }
      selected = (range, url)
      stop.pointee = true
    }
    return selected
  }

  private func valid(_ range: NSRange) -> Bool {
    range.location >= 0 && range.location <= text.length && range.length >= 0
      && range.length <= text.length - range.location
  }

  private func updateLink(_ draft: LinkEdit, url: URL?) {
    defer { cancelLinkEditing() }
    guard valid(draft.range), (text.string as NSString).substring(with: draft.range) == draft.title else { return }
    var current = true
    text.enumerateAttribute(.link, in: draft.range) { value, _, _ in
      current = current && EditorLink.url(from: value) == draft.originalURL
    }
    guard current, url != draft.originalURL else { return }
    edit { result in
      if draft.range.length == 0, let url {
        let label = NSAttributedString(string: url.absoluteString,
          attributes: EditorTextAttributes.make(formatBits: 0).merging([.link: url]) { _, new in new })
        result.insert(label, at: draft.range.location)
        selection = NSRange(location: draft.range.location + label.length, length: 0)
      } else {
        if let url { result.addAttribute(.link, value: url, range: draft.range) }
        else { result.removeAttribute(.link, range: draft.range) }
        selection = NSRange(location: NSMaxRange(draft.range), length: 0)
      }
      typingAttributes.removeValue(forKey: .link)
    }
    textView?.typingAttributes.removeValue(forKey: .link)
  }

  private func photos() -> [PhotoAttachment] {
    var values: [PhotoAttachment] = []
    EditorTextRuns.enumerate(text) { attributes, _ in
      if let photo = attributes[.attachment] as? PhotoAttachment { values.append(photo) }
    }
    return values
  }

  private func photoParagraph(_ id: UUID) -> NSRange? {
    var found: NSRange?
    EditorTextRuns.enumerate(text) { attributes, range in
      guard (attributes[.attachment] as? PhotoAttachment)?.id == id else { return }
      let paragraph = (text.string as NSString).paragraphRange(for: range)
      let content = (text.string as NSString).substring(with: paragraph)
      found = content == "\u{fffc}\n" || content == "\u{fffc}" ? paragraph : range
    }
    return found
  }

  private func rememberPhoto(_ photo: PhotoAttachment) {
    assets[ObjectIdentifier(photo)] = PhotoReference(photo)
    photo.presentation.retry = { [weak self] in self?.retryPhotos() }
  }

  private func restorePhotos() {
    for photo in photos() {
      rememberPhoto(photo)
      if !photo.ready {
        if let session { uploads.start(photo.sourceID, fallback: nil, session: session, service: photoService) }
      } else if textView != nil { loadPreview(photo) }
    }
    observeUploads()
    applyUploadStates(uploads.states.wrappedValue)
  }

  private func loadPreview(_ photo: PhotoAttachment) {
    let url = photo.sourceURL
    guard !photo.hasLoadedPreview, previewLoads[url] == nil else { return }
    let service = photoService
    previewLoads[url] = Task { [weak self] in
      defer { self?.previewLoads[url] = nil }
      do {
        let data = try await service.preview(url)
        guard !Task.isCancelled, let image = PhotoImagePreview.decode(data) else { return }
        self?.applyPreview(image, for: url)
      } catch {}
    }
  }

  private func loadedPhotoPreviews() -> [URL: UIImage] {
    var result: [URL: UIImage] = [:]
    for photo in photos() where photo.hasLoadedPreview {
      result[photo.sourceURL] = photo.image
      result[PhotoAttachment.localURL(photo.sourceID)] = photo.image
    }
    return result
  }

  private func applyPreview(_ image: UIImage, for url: URL) {
    for photo in assets.values.compactMap(\.photo) where photo.sourceURL == url {
      photo.setPreview(image)
      photo.hasLoadedPreview = true
    }
    invalidatePhotos()
  }

  private func observeUploads() {
    guard uploadObservation == nil else { return }
    let states = uploads.states
    uploadObservation = observe { @MainActor [weak self] in
      guard let self else { return }
      applyUploadStates(states.wrappedValue)
    }
  }

  private func applyUploadStates(_ states: [UUID: EditorPhotoUploads.State]) {
    var changed = false
    var previewChanged = false
    let data = uploads.takePreviews()
    var images: [UUID: UIImage] = [:]
    for photo in assets.values.compactMap(\.photo) {
      photo.presentation.state = states[photo.sourceID]
      if !photo.hasLoadedPreview, let bytes = data[photo.sourceID],
         let image = images[photo.sourceID] ?? PhotoImagePreview.decode(bytes) {
        images[photo.sourceID] = image
        photo.setPreview(image)
        photo.hasLoadedPreview = true
        previewChanged = true
      }
      guard case let .uploaded(url) = states[photo.sourceID], !photo.ready || photo.sourceURL != url else { continue }
      photo.ready = true
      photo.sourceURL = url
      if !photo.hasLoadedPreview, textView != nil { loadPreview(photo) }
      changed = true
    }
    if previewChanged { invalidatePhotos() }
    if changed { refresh() } else { updateStatus() }
  }

  private func invalidatePhotos() {
    guard let view = textView, let layout = view.textLayoutManager else { return }
    layout.invalidateLayout(for: layout.documentRange)
    view.setNeedsLayout()
    view.setNeedsDisplay()
  }

  private func updateStatus() {
    updateHistoryStatus()
    hasUnfinishedPhotos = photos().contains { !$0.ready }
  }

  private func updateHistoryStatus() {
    canUndo = history.canUndo
    canRedo = history.canRedo
  }

  private static func isValidPostText(_ source: String) -> Bool {
    !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && source.utf16.count <= Constants.characterLimit
  }
}

@MainActor private final class PhotoReference {
  weak var photo: PhotoAttachment?
  init(_ photo: PhotoAttachment) { self.photo = photo }
}

private enum Constants {
  static let characterLimit = 4096
  static let lineFeed: unichar = 10
}
