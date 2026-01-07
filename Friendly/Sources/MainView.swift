import SwiftUI

struct MainView: View {
    private let viewModel: MainViewModel = MainViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
    }
}
