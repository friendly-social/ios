import SwiftUI

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            if let url = url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } placeholder: {
                    let opacity = colorScheme == .light ? 0.5 : 1
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .background(.white)
                        .foregroundStyle(.gray.gradient.opacity(opacity))
                        .clipShape(Circle())
                        .overlay {
                            ZStack {
                                Circle().fill(.ultraThinMaterial)
                                ProgressView()
                            }
                        }
                }
            } else {
                let opacity = colorScheme == .light ? 0.5 : 1
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(.white)
                    .foregroundStyle(.gray.gradient.opacity(opacity))
                    .clipShape(Circle())
            }
        }
    }
}

