import Foundation
import ImageService
import Nuke

struct ImageServiceLive: Sendable {
  private let pipeline: ImagePipeline

  init(pipeline: ImagePipeline? = nil) { self.pipeline = pipeline ?? Self.makePipeline() }

  func prepare() { ImagePipeline.shared = pipeline }

  func cached(_ url: URL) -> Data? {
    guard Self.valid(url) else { return nil }
    return pipeline.cache.cachedData(for: ImageRequest(url: url))
  }

  func remember(_ data: Data, for url: URL) {
    guard Self.valid(url), data.count <= Constants.maximumBytes else { return }
    let request = ImageRequest(url: url)
    pipeline.cache.storeCachedData(data, for: request)
    if let image = pipeline.cache.cachedImage(for: request, caches: .disk) {
      pipeline.cache.storeCachedImage(image, for: request, caches: .memory)
    }
  }

  func load(_ url: URL) async throws -> Data {
    guard Self.valid(url) else { throw ImageService.Error.invalidURL }
    do {
      let (data, _) = try await pipeline.data(for: ImageRequest(url: url))
      return data
    } catch {
      if Task.isCancelled { throw CancellationError() }
      throw ImageService.Error.unavailable
    }
  }
}

private extension ImageServiceLive {
  private static func makePipeline() -> ImagePipeline {
    var configuration = ImagePipeline.Configuration.withDataCache(
      name: Constants.cacheName, sizeLimit: Constants.diskBytes)
    configuration.imageCache = ImageCache(costLimit: Constants.memoryBytes)
    configuration.maximumResponseDataSize = Constants.maximumBytes
    return ImagePipeline(configuration: configuration)
  }

  private static func valid(_ url: URL) -> Bool {
    ["http", "https"].contains(url.scheme?.lowercased()) && url.host != nil
  }
}

private enum Constants {
  static let cacheName = "ly.getfriend.images"
  static let memoryBytes = 64 * 1024 * 1024
  static let diskBytes = 256 * 1024 * 1024
  static let maximumBytes = 32 * 1024 * 1024
}
