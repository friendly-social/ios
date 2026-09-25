import SwiftUI

@MainActor
@Observable
public final class Router {
    public var path = NavigationPath()

    public init() {}
}
