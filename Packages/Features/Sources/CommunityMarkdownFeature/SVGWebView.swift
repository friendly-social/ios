import SwiftUI
import WebKit

struct SVGWebView: UIViewRepresentable {
  let data: Data

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> WKWebView { Self.makeWebView() }

  static func makeWebView() -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.isOpaque = false
    view.backgroundColor = .clear
    view.scrollView.backgroundColor = .clear
    view.scrollView.isScrollEnabled = false
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ view: WKWebView, context: Context) {
    guard context.coordinator.data != data else { return }
    context.coordinator.data = data
    view.loadHTMLString(Self.html(for: data), baseURL: nil)
  }

  static func html(for data: Data) -> String {
    let encoded = data.base64EncodedString()
    return """
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'">
      <style>html,body{margin:0;width:100%;height:100%;overflow:hidden}img{width:100%;height:100%;object-fit:contain}</style>
      <img src="data:image/svg+xml;base64,\(encoded)">
      """
  }

  final class Coordinator {
    var data: Data?
  }
}
