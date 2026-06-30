import SwiftUI

struct InlineErrorView: View {
    let resource: LocalizedStringResource

    init(_ resource: LocalizedStringResource) {
        self.resource = resource
    }

    var body: some View {
        Text(resource)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }
}
