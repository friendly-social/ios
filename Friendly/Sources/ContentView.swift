import SwiftUI

struct ContentView: View {
    private let viewModel: ContentViewModel = ContentViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            switch viewModel.destination {
            case .empty: EmptyView()
            case .signUp: SignUpView(onComplete: viewModel.onSignUp)
            case .main: MainView(routeToSignUp: viewModel.routeToSignUp)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.destination)
        .transition(.opacity)
        .onAppear {
            viewModel.appear()
        }
    }
}
