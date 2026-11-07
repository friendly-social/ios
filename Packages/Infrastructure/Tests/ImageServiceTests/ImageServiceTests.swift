import Combine
import CustomDump
import Foundation
import ImageService
@testable import ImageServiceLive
import Nuke
import NukeUI
import Synchronization
import Testing
import UIKit

@Suite(.serialized) @MainActor struct ImageServiceTests {
  private let url = URL(string: "https://example.com/photo.jpg")!

  @Test func svgDimensionsUseIntrinsicSizeOrViewBox() {
    let sized = Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"190\" height=\"20\"></svg>".utf8)
    let viewBox = Data("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 88 31\"></svg>".utf8)
    #expect(SVGDimensions.read(sized) == CGSize(width: 190, height: 20))
    #expect(SVGDimensions.read(viewBox) == CGSize(width: 88, height: 31))
  }

  @Test func invalidSvgHasNoDimensions() {
    #expect(SVGDimensions.read(Data("<html width=\"88\" height=\"31\"></html>".utf8)) == nil)
    #expect(SVGDimensions.read(Data("<svg width=\"0\" height=\"31\"></svg>".utf8)) == nil)
  }

  @Test func svgUsesNukeCacheWithoutClearingReadyContent() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"88\" height=\"31\"></svg>".utf8)
    let loader = SVGLoader(data: data)
    let pipeline = try makePipeline(directory, loader: loader)
    let url = try #require(URL(string: "https://example.com/badge"))
    let response = try await pipeline.imageTask(with: url).response
    let svg = try #require(response.container.userInfo[.init(SVGImage.metadataKey)] as? SVGImage)
    expectNoDifference(svg.size, CGSize(width: 88, height: 31))
    let image = FetchImage()
    image.pipeline = pipeline
    image.load(url)
    #expect(!image.isLoading && image.imageContainer != nil)
    var becameEmpty = false
    let observation = image.$imageContainer.dropFirst().sink { if $0 == nil { becameEmpty = true } }
    image.load(url)
    #expect(!becameEmpty && !image.isLoading)
    expectNoDifference(loader.calls.withLock { $0 }, 1)
    withExtendedLifetime(observation) {}
  }

  @Test func svgDecoderRejectsInvalidContent() throws {
    let data = Data("<svg width=\"0\" height=\"20\"></svg>".utf8)
    let context = ImageDecodingContext(request: ImageRequest(url: url), data: data)
    let decoder = try #require(SVGImageDecoder(context: context))
    #expect(throws: (any Error).self) { try decoder.decode(data) }
  }

  @Test func uploadedBytesAreAvailableToUIKitAndSwiftUIWithoutDownloading() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let pipeline = try makePipeline(directory)
    let live = ImageServiceLive(pipeline: pipeline)
    let original = ImagePipeline.shared
    defer { ImagePipeline.shared = original }
    live.prepare()
    let data = try imageData()
    live.remember(data, for: url)
    expectNoDifference(live.cached(url), data)
    #expect(ImagePipeline.shared === pipeline)
    let swiftUI = FetchImage()
    swiftUI.load(url)
    #expect(swiftUI.imageContainer != nil)
    #expect(!swiftUI.isLoading)
    expectNoDifference(swiftUI.imageContainer?.image.size, CGSize(width: 100, height: 200))
  }

  @Test func uploadedBytesSurviveIndependentCacheWithEmptyMemory() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try imageData()
    try persist(data, at: directory)
    let pipeline = try makePipeline(directory)
    #expect(pipeline.cache[url] == nil)
    let live = ImageServiceLive(pipeline: pipeline)
    expectNoDifference(live.cached(url), data)
  }

  @Test func failedDownloadCanRetryAndCompletedDownloadIsCached() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let loader = RetryLoader(data: try imageData())
    let pipeline = try makePipeline(directory, loader: loader)
    let live = ImageServiceLive(pipeline: pipeline)
    await #expect(throws: ImageService.Error.unavailable) { try await live.load(url) }
    expectNoDifference(live.cached(url), nil)
    let first = try await live.load(url)
    let second = try await live.load(url)
    expectNoDifference(first, loader.data)
    expectNoDifference(second, loader.data)
    expectNoDifference(live.cached(url), loader.data)
    expectNoDifference(loader.calls.withLock { $0 }, 2)
  }

  @Test func invalidURLsDoNotEnterTheCacheOrLoader() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let loader = RetryLoader(data: try imageData())
    let live = ImageServiceLive(pipeline: try makePipeline(directory, loader: loader))
    let invalid = URL(fileURLWithPath: "/image.jpg")
    live.remember(loader.data, for: invalid)
    expectNoDifference(live.cached(invalid), nil)
    await #expect(throws: ImageService.Error.invalidURL) { try await live.load(invalid) }
    expectNoDifference(loader.calls.withLock { $0 }, 0)
  }
}

private extension ImageServiceTests {
  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
  }

  private func makePipeline(_ directory: URL, loader: (any DataLoading)? = nil) throws -> ImagePipeline {
    let cache = try DataCache(path: directory)
    var configuration = ImagePipeline.Configuration()
    configuration.dataCache = cache
    configuration.imageCache = ImageCache()
    configuration.makeImageDecoder = ImageServiceLive.decoder
    if let loader { configuration.dataLoader = loader }
    return ImagePipeline(configuration: configuration)
  }

  private func persist(_ data: Data, at directory: URL) throws {
    let pipeline = try makePipeline(directory)
    ImageServiceLive(pipeline: pipeline).remember(data, for: url)
    (pipeline.configuration.dataCache as? DataCache)?.flush()
  }

  private func imageData() throws -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image {
      $0.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
    }
    return try #require(image.pngData())
  }
}

private final class RetryLoader: DataLoading {
  let data: Data
  let calls = Mutex(0)

  init(data: Data) { self.data = data }

  func loadData(
    with request: URLRequest, didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
    completion: @escaping @Sendable ((any Swift.Error)?) -> Void
  ) -> any Nuke.Cancellable {
    let count = calls.withLock { $0 += 1; return $0 }
    if count == 1 { completion(URLError(.badServerResponse)) }
    else {
      let response = URLResponse(url: request.url!, mimeType: "image/png",
        expectedContentLength: data.count, textEncodingName: nil)
      didReceiveData(data, response)
      completion(nil)
    }
    return NoopCancellation()
  }
}

private struct NoopCancellation: Nuke.Cancellable {
  func cancel() {}
}

private final class SVGLoader: DataLoading {
  let data: Data
  let calls = Mutex(0)

  init(data: Data) { self.data = data }

  func loadData(
    with request: URLRequest, didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
    completion: @escaping @Sendable ((any Swift.Error)?) -> Void
  ) -> any Nuke.Cancellable {
    calls.withLock { $0 += 1 }
    let response = URLResponse(url: request.url!, mimeType: "image/svg+xml",
      expectedContentLength: data.count, textEncodingName: nil)
    didReceiveData(data, response)
    completion(nil)
    return NoopCancellation()
  }
}
