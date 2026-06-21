import SwiftUI

struct InlineErrorView: View {
    let key: LocalizedStringKey

    var body: some View {
        Text(key)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }
}
