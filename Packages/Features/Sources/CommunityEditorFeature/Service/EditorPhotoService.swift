import CommunityProfileService
import Dependencies
import DependenciesMacros
import Foundation
import PhotosUI
import SwiftUI

@DependencyClient
public struct EditorPhotoService: Sendable {
  public var selectionData: @Sendable (PhotosPickerItem) async throws -> Data
  public var restore: @Sendable (UUID, Data?, CommunitySession) async throws -> EditorPhotoContent
  public var upload: @Sendable (UUID, CommunitySession) async throws -> URL
  public var preview: @Sendable (URL) async throws -> Data
  public var cachedPreview: @Sendable (URL) -> Data? = { _ in nil }
}

public struct EditorPhotoContent: Sendable {
  public let preview: Data
  public let uploadedURL: URL?

  public init(preview: Data, uploadedURL: URL? = nil) {
    self.preview = preview
    self.uploadedURL = uploadedURL
  }
}

public enum EditorPhotoError: Error, Sendable {
  case invalidImage
  case missingOriginal
  case unavailable
}

extension EditorPhotoService: TestDependencyKey {
  public static var testValue: Self {
    var value = Self()
    value.preview = { _ in throw EditorPhotoError.unavailable }
    // Explicit assignment marks this endpoint as implemented for tests.
    value.cachedPreview = { _ in nil }
    return value
  }
}
