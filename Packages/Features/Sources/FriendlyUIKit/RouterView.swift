import SwiftUI

public struct RouterView<Content: View>: View {
    @State private var router = Router()
    @ViewBuilder var content: (Router) -> Content

    public init(@ViewBuilder content: @escaping (Router) -> Content) {
        self.content = content
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            content(router)
        }
    }
}
