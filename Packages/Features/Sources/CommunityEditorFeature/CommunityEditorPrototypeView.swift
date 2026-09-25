import SwiftUI

public struct CommunityEditorPrototypeView: View {
  @State private var editor = CommunityEditorViewModel(source: CommunityEditorSamples.completeSample)

  public init() {}

  public var body: some View {
    contentView()
  }
}

private extension CommunityEditorPrototypeView {

  @ViewBuilder
  private func contentView() -> some View {
    NavigationStack {
      CommunityEditorView(viewModel: editor, showsSamples: true)
        .navigationTitle(
          .composerTitle
        )
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview { CommunityEditorPrototypeView() }
