import CommunityProfileService
import Foundation
import Sharing

@MainActor final class EditorPhotoUploads {
  enum State: Equatable {
    case preparing
    case uploading
    case failed
    case uploaded(URL)
  }

  @Shared private var values: [UUID: State]
  private var pending: [UUID: Task<Void, Never>] = [:]
  private var prepared: [UUID: Task<EditorPhotoContent, Error>] = [:]
  private var previews: [UUID: Data] = [:]

  var states: SharedReader<[UUID: State]> { SharedReader($values) }

  init() { _values = Shared(value: [:]) }

  deinit { pending.values.forEach { $0.cancel() } }

  func remember(_ id: UUID, url: URL) {
    guard case .uploaded = values[id] else {
      $values.withLock { $0[id] = .uploaded(url) }
      return
    }
  }

  func start(_ id: UUID, fallback: @autoclosure () -> Data?, session: CommunitySession, service: EditorPhotoService) {
    guard values[id] == nil else { return }
    $values.withLock { $0[id] = .preparing }
    let data = fallback()
    let preparation = Task { try await service.restore(id, data, session) }
    prepared[id] = preparation
    pending[id] = Task { [weak self] in
      do {
        let content = try await preparation.value
        guard !Task.isCancelled else { return }
        self?.previews[id] = content.preview
        let url: URL
        if let uploaded = content.uploadedURL { url = uploaded }
        else {
          self?.$values.withLock { $0[id] = .uploading }
          url = try await service.upload(id, session)
        }
        guard !Task.isCancelled else { return }
        self?.remember(id, url: url)
      } catch {
        guard !Task.isCancelled else { return }
        self?.$values.withLock { $0[id] = .failed }
      }
      self?.pending[id] = nil
      self?.prepared[id] = nil
    }
  }

  func retry(_ id: UUID, fallback: @autoclosure () -> Data?, session: CommunitySession, service: EditorPhotoService) {
    guard values[id] == .failed else { return }
    $values.withLock { $0[id] = nil }
    start(id, fallback: fallback(), session: session, service: service)
  }

  func takePreviews() -> [UUID: Data] {
    let result = previews
    previews.removeAll()
    return result
  }

  func prepareForSaving() async throws {
    for task in prepared.values { _ = try await task.value }
  }
}
