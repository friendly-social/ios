import DependenciesMacros
import PhotosUI
import SwiftUI

@DependencyClient
public struct QRPhotoImportService: Sendable {
  public var code: @Sendable (PhotosPickerItem) async throws -> String
}

extension QRPhotoImportService {
  public enum ImportError: Error {
    case invalidImage
    case codeNotFound
  }
}
