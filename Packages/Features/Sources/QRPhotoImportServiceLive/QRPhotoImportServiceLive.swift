import PhotosUI
import QRCode
import QRPhotoImportService
import SwiftUI
import UIKit

struct QRPhotoImportServiceLive {
  func code(from item: PhotosPickerItem) async throws -> String {
    guard let data = try await item.loadTransferable(type: Data.self),
          let image = UIImage(data: data), let cgImage = image.cgImage else {
      throw QRPhotoImportService.ImportError.invalidImage
    }
    guard let code = cgImage.detectQRCodeStrings().first(where: { !$0.isEmpty }) else {
      throw QRPhotoImportService.ImportError.codeNotFound
    }
    return code
  }
}
