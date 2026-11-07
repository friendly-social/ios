@testable import CommunityMarkdownFeature
import Foundation
import SwiftUI
import Testing
import UIKit
import WebKit

@MainActor
struct MarkdownImageLayoutTests {
  @Test func remembersDimensionsAndIgnoresInvalidMeasurements() throws {
    let cache = MarkdownImageLayoutCache()
    let url = try #require(URL(string: "https://example.com/photo.jpg"))
    #expect(cache.size(for: url) == nil)
    cache.record(size: CGSize(width: 300, height: 150), for: url)
    #expect(cache.size(for: url) == CGSize(width: 300, height: 150))
    cache.record(size: .zero, for: url)
    cache.record(size: CGSize(width: CGFloat.infinity, height: 100), for: url)
    #expect(cache.size(for: url) == CGSize(width: 300, height: 150))
    cache.record(size: CGSize(width: 600, height: 300), for: url)
    #expect(cache.size(for: url) == CGSize(width: 600, height: 300))
  }

  @Test func cachedLayoutDoesNotDependOnLoadingContent() {
    let loading = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: CGSize(width: 300, height: 150), maximumHeight: 320) { ProgressView() })
    let loaded = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: CGSize(width: 300, height: 150), maximumHeight: 320) { Color.red })
    let proposal = CGSize(width: 300, height: 1000)
    #expect(loading.sizeThatFits(in: proposal) == CGSize(width: 300, height: 150))
    #expect(loaded.sizeThatFits(in: proposal) == loading.sizeThatFits(in: proposal))
    #expect(loaded.sizeThatFits(in: CGSize(width: 200, height: 1000))
      == CGSize(width: 200, height: 100))
  }

  @Test func svgViewRendersBadgeLogoAndReadout() async throws {
    let size = CGSize(width: 190.4, height: 20)
    let image = try await renderedSVG(Data(Constants.badge.utf8), size: size)
    #expect(try whitePixels(image, in: CGRect(x: 5, y: 3, width: 14, height: 14)) > 20)
    #expect(try whitePixels(image, in: CGRect(x: 20, y: 0, width: 60, height: 20)) > 20)
    #expect(try whitePixels(image, in: CGRect(x: 81, y: 0, width: 109, height: 20)) > 20)
    Attachment.record(image, named: "wakatime-webkit")
  }

  @Test func smallImagesAreNotUpscaled() {
    let controller = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: CGSize(width: 88, height: 31), maximumHeight: 320) { Color.red })
    #expect(controller.sizeThatFits(in: CGSize(width: 300, height: 1000)) == CGSize(width: 88, height: 31))
    let scaled = controller.sizeThatFits(in: CGSize(width: 44, height: 1000))
    #expect(scaled.width == 44)
    #expect(abs(scaled.height - 15.5) < 0.5)
  }

  @Test func htmlWidthOnlyKeepsTallImageWithinHeightLimit() {
    let controller = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: CGSize(width: 100, height: 1000), maximumHeight: 320,
                          width: 320) { Color.red })
    #expect(controller.sizeThatFits(in: CGSize(width: 293, height: 5000)) == CGSize(width: 32, height: 320))
  }

  @Test func htmlDimensionsFitNarrowColumns() {
    let controller = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: CGSize(width: 400, height: 100), maximumHeight: 320,
                          width: 320, height: 80) { Color.red })
    #expect(controller.sizeThatFits(in: CGSize(width: 200, height: 1000)) == CGSize(width: 200, height: 50))
  }

  @Test func htmlHeightOnlyPreservesImageRatio() {
    let controller = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: CGSize(width: 400, height: 100), maximumHeight: 320,
                          height: 50) { Color.red })
    #expect(controller.sizeThatFits(in: CGSize(width: 300, height: 1000)) == CGSize(width: 200, height: 50))
  }

  @Test func explicitHtmlDimensionsBoundLoadingPlaceholder() {
    let controller = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: nil, maximumHeight: 320, width: 23, height: 23) {
        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
      })
    #expect(controller.sizeThatFits(in: CGSize(width: 300, height: 1000)) == CGSize(width: 23, height: 23))
  }

  @Test func portraitLayoutKeepsHeightLimit() {
    let controller = UIHostingController(rootView:
      MarkdownImageLayout(intrinsicSize: CGSize(width: 500, height: 1000), maximumHeight: 320) { Color.red })
    #expect(controller.sizeThatFits(in: CGSize(width: 300, height: 1000))
      == CGSize(width: 160, height: 320))
  }
}

private extension MarkdownImageLayoutTests {
  func renderedSVG(_ data: Data, size: CGSize) async throws -> UIImage {
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(origin: .zero, size: size)
    let controller = UIViewController()
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let webView = SVGWebView.makeWebView()
    webView.frame = CGRect(origin: .zero, size: size)
    controller.view.addSubview(webView)
    let delegate = SVGNavigationProbe()
    webView.navigationDelegate = delegate
    try await delegate.load(webView, html: SVGWebView.html(for: data))
    let width = try await webView.evaluateJavaScript("document.images[0].naturalWidth") as? Int
    #expect(width == 190)
    return try renderPDF(await webView.pdf(), size: size)
  }

  func renderPDF(_ data: Data, size: CGSize) throws -> UIImage {
    let provider = try #require(CGDataProvider(data: data as CFData))
    let document = try #require(CGPDFDocument(provider))
    let page = try #require(document.page(at: 1))
    return UIGraphicsImageRenderer(size: size).image { context in
      context.cgContext.translateBy(x: 0, y: size.height)
      context.cgContext.scaleBy(x: 1, y: -1)
      context.cgContext.drawPDFPage(page)
    }
  }

  func whitePixels(_ image: UIImage, in rect: CGRect) throws -> Int {
    let cgImage = try #require(image.cgImage)
    let region = rect.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))
    let crop = try #require(cgImage.cropping(to: region))
    var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
    let context = try #require(CGContext(
      data: &bytes,
      width: crop.width,
      height: crop.height,
      bitsPerComponent: 8,
      bytesPerRow: crop.width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
    return stride(from: 0, to: bytes.count, by: 4).filter {
      bytes[$0] > 200 && bytes[$0 + 1] > 200 && bytes[$0 + 2] > 200 && bytes[$0 + 3] > 200
    }.count
  }
}

@MainActor
private final class SVGNavigationProbe: NSObject, WKNavigationDelegate {
  private var continuation: CheckedContinuation<Void, any Error>?

  func load(_ view: WKWebView, html: String) async throws {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      view.loadHTMLString(html, baseURL: nil)
    }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    continuation?.resume()
    continuation = nil
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}

private enum Constants {
  static let badge = #"""
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="190.4" height="20"><linearGradient id="smooth" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><clipPath id="round"><rect width="190.4" height="20" rx="3" fill="#fff"/></clipPath><g clip-path="url(#round)"><rect width="80.7" height="20" fill="#555"/><rect x="80.7" width="109.7" height="20" fill="#007ec6"/><rect width="190.4" height="20" fill="url(#smooth)"/></g><g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="110"><image x="5" y="3" width="14" height="14" xlink:href="data:image/svg+xml;utf8,&lt;svg width=&quot;340&quot; height=&quot;340&quot; viewBox=&quot;0 0 340 340&quot; fill=&quot;none&quot; xmlns=&quot;http://www.w3.org/2000/svg&quot;&gt; &lt;path fill-rule=&quot;evenodd&quot; clip-rule=&quot;evenodd&quot; d=&quot;M170 20C87.156 20 20 87.156 20 170C20 252.844 87.156 320 170 320C252.844 320 320 252.844 320 170C320 87.156 252.844 20 170 20V20V20Z&quot; stroke=&quot;white&quot; stroke-width=&quot;40&quot;/&gt; &lt;path d=&quot;M190.183 213.541C188.74 215.443 186.576 216.667 184.151 216.667C183.913 216.667 183.677 216.651 183.443 216.627C183.042 216.579 182.823 216.545 182.606 216.497C182.337 216.434 182.137 216.375 181.94 216.308C181.561 216.176 181.392 216.109 181.228 216.035C180.843 215.849 180.707 215.778 180.572 215.701C180.205 215.478 180.109 215.412 180.014 215.345C179.856 215.233 179.698 215.117 179.547 214.992C179.251 214.746 179.147 214.65 179.044 214.552C178.731 214.241 178.531 214.018 178.341 213.785C177.982 213.331 177.69 212.888 177.438 212.415L168.6 198.214L159.766 212.415C158.38 214.939 155.874 216.667 152.995 216.667C150.106 216.667 147.588 214.926 146.243 212.346L107.607 156.061C106.337 154.529 105.556 152.499 105.556 150.258C105.556 145.514 109.043 141.665 113.344 141.665C116.127 141.665 118.564 143.282 119.942 145.708L152.555 193.9L161.735 178.952C163.058 176.288 165.626 174.478 168.575 174.478C171.273 174.478 173.652 175.996 175.049 178.298L184.517 193.839L235.684 120.583C237.075 118.226 239.475 116.667 242.213 116.667C246.514 116.667 250 120.514 250 125.258C250 127.332 249.337 129.232 248.23 130.715L190.183 213.541V213.541Z&quot; fill=&quot;white&quot; stroke=&quot;white&quot; stroke-width=&quot;10&quot;/&gt; &lt;/svg&gt; "/><text x="498.5" y="150" fill="#010101" fill-opacity=".3" transform="scale(0.1)" textLength="537.0" lengthAdjust="spacing">wakatime</text><text x="498.5" y="140" transform="scale(0.1)" textLength="537.0" lengthAdjust="spacing">wakatime</text><text x="1345.5" y="150" fill="#010101" fill-opacity=".3" transform="scale(0.1)" textLength="997.0" lengthAdjust="spacing">1,234 hrs 56 mins</text><text x="1345.5" y="140" transform="scale(0.1)" textLength="997.0" lengthAdjust="spacing">1,234 hrs 56 mins</text><a xlink:href="https://wakatime.com/"><rect width="80.7" height="20" fill="rgba(0,0,0,0)"/></a><a xlink:href="https://wakatime.com/"><rect x="80.7" width="109.7" height="20" fill="rgba(0,0,0,0)"/></a></g></svg>
    """#
}
