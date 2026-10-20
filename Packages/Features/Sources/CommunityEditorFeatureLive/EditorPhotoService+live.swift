import CommunityEditorFeature
import Dependencies

extension EditorPhotoService: DependencyKey {
  public static var liveValue: Self {
    let live = EditorPhotoServiceLive()
    return .init(
      selectionData: { try await live.selectionData($0) },
      restore: { try await live.restore($0, fallback: $1, session: $2) },
      upload: { try await live.upload($0, session: $1) },
      preview: { try await live.preview($0) },
      cachedPreview: { live.cachedPreview($0) }
    )
  }
}
