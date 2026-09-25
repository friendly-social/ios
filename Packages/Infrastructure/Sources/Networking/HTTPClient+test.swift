import Dependencies
import Foundation

extension HTTPClient: TestDependencyKey {
  public static var testValue: Self {
    .init(baseURL: URL(fileURLWithPath: "/"), transport: .init())
  }
}
