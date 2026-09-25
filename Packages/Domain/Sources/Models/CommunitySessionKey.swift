import CryptoKit
import Foundation

public enum CommunitySessionKey {
  public static func make(_ token: String) -> String {
    SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}
