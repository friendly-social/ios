import Foundation

enum EditorLink {
  static func url(from value: Any?) -> URL? {
    let url: URL?
    if let value = value as? URL { url = value }
    else if let value = value as? String { url = URL(string: value) }
    else { url = nil }
    guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
          let host = url.host, !host.isEmpty else { return nil }
    return url
  }
}
