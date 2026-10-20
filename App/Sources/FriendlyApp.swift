import Dependencies
import ImageService
import SwiftUI

@main
struct FriendlyApp: App {
  @Dependency(ImageService.self) private var images

  init() { images.prepare() }

  var body: some Scene {
    WindowGroup { ContentView() }
  }
}
