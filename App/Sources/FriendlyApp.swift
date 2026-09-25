import Foundation
import SwiftUI

@main
struct FriendlyApp: App {
    init() {
        URLCache.shared.memoryCapacity = Constants.imageCacheMemoryCapacity
        URLCache.shared.diskCapacity = Constants.imageCacheDiskCapacity
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private enum Constants {
    static let imageCacheMemoryCapacity = 32 * 1024 * 1024
    static let imageCacheDiskCapacity = 200 * 1024 * 1024
}
