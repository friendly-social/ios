import CommunityEditorFeature
import CommunityProfileService
import Dependencies
import FilesApi
import Foundation
import ImageService
import PhotosUI
import SwiftUI

struct EditorPhotoServiceLive: Sendable {
  @Dependency(CommunityProfileService.self) private var profile
  @Dependency(FilesApi.self) private var files
  @Dependency(ImageService.self) private var images
  private let store: EditorPhotoStore

  init(directory: URL = URL.applicationSupportDirectory.appending(
    path: "CommunityEditorPhotos", directoryHint: .isDirectory
  )) {
    store = EditorPhotoStore(directory: directory)
  }

  func selectionData(_ item: PhotosPickerItem) async throws -> Data {
    try await mapErrors {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        throw EditorPhotoError.invalidImage
      }
      return data
    }
  }

  func restore(_ id: UUID, fallback: Data?, session: CommunitySession) async throws -> EditorPhotoContent {
    guard profile.isCurrentSession(session) else { throw CancellationError() }
    return try await mapErrors { try await store.restore(id, fallback: fallback, session: session) }
  }

  func upload(_ id: UUID, session: CommunitySession) async throws -> URL {
    let profile = profile
    let files = files
    let images = images
    guard profile.isCurrentSession(session) else { throw CancellationError() }
    return try await mapErrors {
      try await store.upload(id, session: session) { data in
        guard profile.isCurrentSession(session) else { throw CancellationError() }
        let file = try await files.uploadAuthorized(data, .init(accountID: session.accountID, token: session.token))
        guard profile.isCurrentSession(session) else { throw CancellationError() }
        let url = files.downloadURL(for: file)
        images.remember(data, url)
        return url
      }
    }
  }

  func preview(_ url: URL) async throws -> Data {
    try await mapErrors { try await images.load(url) }
  }

  func cachedPreview(_ url: URL) -> Data? { images.cached(url) }
}

private extension EditorPhotoServiceLive {
  private func mapErrors<Value: Sendable>(_ operation: () async throws -> Value) async throws -> Value {
    do { return try await operation() }
    catch let error as EditorPhotoError { throw error }
    catch ImageService.Error.invalidURL { throw EditorPhotoError.invalidImage }
    catch is CancellationError { throw CancellationError() }
    catch { throw EditorPhotoError.unavailable }
  }
}
