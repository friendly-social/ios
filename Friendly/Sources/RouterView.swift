import SwiftUI

struct RouterView<Content: View>: View {
    @State private var router = Router()
    @ViewBuilder var content: (Router) -> Content

    var body: some View {
        NavigationStack(path: $router.path) {
            content(router)
        }
    }
}
