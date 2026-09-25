import Dependencies
import FilesApi

extension FilesApi {
  public static func live() -> Self {
    let live = FilesApiLive()
    return .init(
      upload: { try await live.upload($0) },
      downloadURL: { live.downloadURL(for: $0) })
  }
}

extension FilesApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
