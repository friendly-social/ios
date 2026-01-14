import SwiftUI
import Flow

struct FeedSwipeCardView: View {
    @State private var translation: CGSize = .zero
    @State private var dragDirection: DragDirection? = nil
    @State private var swipeStatus: LikeDislike = .none {
        didSet {
            if swipeStatus == .like {
                onLike()
            }
            if swipeStatus == .dislike {
                onDislike()
            }
        }
    }

    let avatarUrl: URL?
    let nickname: Nickname
    let description: UserDescription
    let interests: [Interest]
    let onLike: () -> Void
    let onDislike: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack {
                VStack {
                    Avatar(url: avatarUrl).overlay {
                        VStack {
                            Spacer()
                            Interests(
                                dragDirection: $dragDirection,
                                interests: interests,
                            )
                            .padding(.bottom)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(nickname.string)
                            .font(.title2)
                            .bold()
                        Text(description.string)
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(role: .destructive) {
                    runActionWithAnimation(for: .dislike)
                } label: {
                    Image(systemName: "xmark")
                        .bold()
                        .padding()
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .regular.tint(.gray.opacity(0.2)).interactive(),
                    in: Circle(),
                )
                Spacer()
                Button(role: .confirm) {
                    runActionWithAnimation(for: .like)
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .bold()
                        .padding()
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .regular.tint(.accentColor).interactive(),
                    in: Circle(),
                )
                .contentShape(Rectangle())
            }
            .padding(.bottom)
            .padding(.horizontal)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: .black.opacity(0.05),
            radius: 10,
        )
        .offset(x: translation.width, y: translation.height)
        .rotationEffect(.degrees(Double(translation.width / 40)))
        .scrollDisabled(dragDirection == .horizontal)
        .scrollBounceBehavior(.basedOnSize)
        .simultaneousGesture(
            DragGesture()
                .onChanged { gesture in
                    if dragDirection == nil {
                        let horizontalAmount = abs(gesture.translation.width)
                        let verticalAmount = abs(gesture.translation.height)
                        if horizontalAmount > 5 || verticalAmount > 5 {
                            dragDirection = horizontalAmount > verticalAmount
                                ? .horizontal
                                : .vertical
                        }
                    }
                    if dragDirection == .horizontal {
                        translation = gesture.translation
                    }
                }.onEnded { _ in
                    withAnimation {
                        swipeCard(width: translation.width)
                    }
                    dragDirection = nil
                }
        )
    }

    private func swipeCard(width: CGFloat) {
        switch width {
        case -500...(-150):
            swipeStatus = .dislike
            translation = CGSize(width: -500, height: 0)
        case 150...500:
            swipeStatus = .like
            translation = CGSize(width: 500, height: 0)
        default:
            translation = .zero
            swipeStatus = .none
        }
    }

    private func runActionWithAnimation(for actionType: LikeDislike) {

        let width: CGFloat = switch actionType {
        case .like: 500
        case .dislike: -500
        case .none: 0
        }

        withAnimation {
            swipeCard(width: width)
        }
    }

}

private enum DragDirection {
    case horizontal
    case horizontalBlocked
    case vertical
}

private enum LikeDislike: Int {
    case like, dislike, none
}

private struct Avatar: View {
    let url: URL?

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(1 / 1, contentMode: .fit)
                } placeholder: {
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(1 / 1, contentMode: .fit)
                        .background(.gray)
                        .foregroundStyle(.white)
                        .overlay {
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                ProgressView()
                            }
                        }
                }
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .aspectRatio(1 / 1, contentMode: .fit)
                    .background(.gray)
                    .foregroundStyle(.white)
            }
        }
        .overlay {
            let gradient = LinearGradient(
                gradient: Gradient(
                    colors: [.clear, .black],
                ),
                startPoint: .top,
                endPoint: .bottom,
            )
            VStack {
                Spacer()
                Color(.clear)
                    .background(.ultraThinMaterial)
                    .frame(height: 100)
                    .mask(gradient)
            }
        }
    }
}

private struct Interests: View {
    @Binding var dragDirection: DragDirection?
    let interests: [Interest]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Spacer()
                    .frame(width: 10)
                ForEach(interests, id: \.string) { interest in
                    ChipView(text: interest.string)
                }
                Spacer()
                    .frame(width: 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    dragDirection = .horizontalBlocked
                }
                .onEnded { _ in
                    dragDirection = nil
                }
        )
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(
                        colors: [.clear, .black],
                    ),
                    startPoint: .leading,
                    endPoint: .trailing,
                )
                .frame(width: 10)
                Rectangle().fill(.black)
                LinearGradient(
                    gradient: Gradient(
                        colors: [.clear, .black],
                    ),
                    startPoint: .trailing,
                    endPoint: .leading,
                )
                .frame(width: 10)
            }
        )
    }
}
