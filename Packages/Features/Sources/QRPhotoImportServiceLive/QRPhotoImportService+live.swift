import Dependencies
import QRPhotoImportService

extension QRPhotoImportService: DependencyKey {
  public static var liveValue: Self {
    let live = QRPhotoImportServiceLive()
    return .init(code: { item in try await live.code(from: item) })
  }
}
