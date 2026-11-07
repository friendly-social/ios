import FriendlyUIKit
import Models
import NukeUI
import SwiftUI

struct FeedSwipeCardView: View {
  @State private var translation: CGSize = .zero
  @State private var dragDirection: DragDirection?
  @State private var swipeStatus: SwipeAction = .none {
    didSet {
      if swipeStatus == .like { entry.onLike() }
      if swipeStatus == .dislike { entry.onDislike() }
    }
  }
  private let entry: FeedViewModel.Entry

  init(entry: FeedViewModel.Entry) {
    self.entry = entry
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack {
        avatarView()
        descriptionView()
      }
    }
    .safeAreaInset(edge: .bottom) { actionsView() }
    .background(Constants.background)
    .overlay { SwipeFeedbackView(translation: translation.width) }
    .clipShape(.rect(cornerRadius: Constants.cornerRadius))
    .shadow(color: Constants.shadowColor, radius: Constants.shadowRadius)
    .offset(x: translation.width, y: translation.height)
    .rotationEffect(.degrees(Double(translation.width / Constants.rotationSensitivity)))
    .scrollDisabled(dragDirection == .horizontal)
    .scrollBounceBehavior(.basedOnSize)
    .simultaneousGesture(cardGesture())
  }
}

private extension FeedSwipeCardView {
  private func avatarView() -> some View {
    CandidateAvatarView(url: entry.avatarUrl).overlay {
      VStack {
        if entry.isRequest {
          CandidateBadgeView(title: .feedLikedYou)
        } else if entry.isExtendedNetwork {
          CandidateBadgeView(title: .feedExtendedNetwork)
        }
        Spacer()
        CandidateInterestsView(
          dragDirection: $dragDirection,
          interests: entry.interests,
        )
        .padding(.bottom)
      }
    }
  }

  private func descriptionView() -> some View {
    VStack(alignment: .leading) {
      Text(entry.nickname.string)
        .font(.title2)
        .bold()
        .padding(.bottom, Constants.nameBottomPadding)
      ExpandableDescriptionView(text: entry.description.string)
        .font(.subheadline)
        .truncationMode(.tail)
        .lineLimit(Constants.cardDescriptionLineLimit)
    }
    .padding(.horizontal)
    .padding(.bottom)
    .padding(.top, Constants.descriptionTopPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func dislikeButton() -> some View {
    Button(role: .destructive) {
      runActionWithAnimation(for: .dislike)
    } label: {
      Image(systemName: Constants.dislikeSymbol)
        .bold()
        .padding()
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassEffect(
      .regular.tint(.gray.opacity(Constants.glassTintOpacity)).interactive(),
      in: Circle(),
    )
  }

  private func likeButton() -> some View {
    Button(role: .confirm) {
      runActionWithAnimation(for: .like)
    } label: {
      Image(systemName: Constants.likeSymbol)
        .foregroundStyle(Constants.confirmForeground)
        .bold()
        .padding()
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassEffect(
      .regular.tint(.accentColor).interactive(),
      in: Circle(),
    )
    .contentShape(.rect)
  }

  private func actionsView() -> some View {
    HStack {
      dislikeButton()
      Spacer()
      commonFriendsButton()
      Spacer()
      likeButton()
    }
    .padding(.bottom)
    .padding(.horizontal)
    .background { CardActionsBackgroundView() }
  }

  @ViewBuilder
  private func commonFriendsButton() -> some View {
    if !entry.friendsPreview.avatars.isEmpty {
      Button(action: entry.onOpenFriends) {
        FriendsAvatarsView(preview: entry.friendsPreview)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(.feedCommonFriends)
    }
  }

  private func cardGesture() -> some Gesture {
    DragGesture()
      .onChanged(handleDragChanged)
      .onEnded { _ in handleDragEnded() }
  }

  private func handleDragChanged(_ gesture: DragGesture.Value) {
    if dragDirection == nil {
      let horizontalAmount = abs(gesture.translation.width)
      let verticalAmount = abs(gesture.translation.height)
      if horizontalAmount > Constants.dragThreshold || verticalAmount > Constants.dragThreshold {
        dragDirection = horizontalAmount > verticalAmount ? .horizontal : .vertical
      }
    }
    if dragDirection == .horizontal { translation = gesture.translation }
  }

  private func handleDragEnded() {
    withAnimation { swipeCard(width: translation.width) }
    dragDirection = nil
  }

  private func swipeCard(width: CGFloat) {
    switch width {
    case (-Constants.swipeExitDistance)...(-Constants.swipeThreshold):
      swipeStatus = .dislike
      translation = CGSize(width: -Constants.swipeExitDistance, height: Constants.zero)
    case Constants.swipeThreshold...Constants.swipeExitDistance:
      swipeStatus = .like
      translation = CGSize(width: Constants.swipeExitDistance, height: Constants.zero)
    default:
      translation = .zero
      swipeStatus = .none
    }
  }

  private func runActionWithAnimation(for actionType: SwipeAction) {
    let width: CGFloat = switch actionType {
    case .like: Constants.swipeExitDistance
    case .dislike: -Constants.swipeExitDistance
    case .none: Constants.zero
    }
    withAnimation {
      swipeCard(width: width)
    }
  }
}

private struct SwipeFeedbackView: View {
  private let translation: CGFloat

  init(translation: CGFloat) {
    self.translation = translation
  }

  var body: some View {
    if translation < -Constants.overlayStartDistance {
      feedbackView(color: Constants.dislikeColor)
    }
    if translation > Constants.overlayStartDistance {
      feedbackView(color: Constants.likeColor)
    }
  }
}

private extension SwipeFeedbackView {
  private var progress: Double {
    Double((min(Constants.overlayFullDistance, abs(translation)) - Constants.overlayStartDistance) / Constants.overlayRange)
  }

  private func feedbackView(color: Color) -> some View {
    ZStack {
      color.opacity(Constants.overlayColorOpacity * progress)
      Rectangle().fill(.ultraThinMaterial.opacity(Constants.overlayMaterialOpacity * progress))
    }
  }
}

private struct ExpandableDescriptionView: View {
  @State private var isExpanded = false
  @State private var isTruncated = false
  private let text: String

  init(text: String) {
    self.text = text
  }

  var body: some View {
    VStack(alignment: .trailing) {
      Text(text)
        .lineLimit(isExpanded ? nil : Constants.collapsedDescriptionLineLimit)
        .background { truncationProbeView() }
      Spacer().frame(height: Constants.expandButtonSpacing)
      if isTruncated && !isExpanded { expandButton() }
    }
  }
}

private extension ExpandableDescriptionView {
  private func truncationProbeView() -> some View {
    ViewThatFits(in: .vertical) {
      Text(text).lineLimit(nil).hidden()
      Color.clear.onAppear { isTruncated = true }
    }
  }

  private func expandButton() -> some View {
    Button(.feedExpand) {
      withAnimation { isExpanded = true }
    }
    .fontWeight(.bold)
  }
}

private enum DragDirection {
  case horizontal
  case horizontalBlocked
  case vertical
}

private enum SwipeAction {
  case like, dislike, none
}

private struct CandidateAvatarView: View {
  private let url: URL?

  init(url: URL?) {
    self.url = url
  }

  var body: some View { imageView().overlay { bottomGradientView() } }
}

private extension CandidateAvatarView {
  @ViewBuilder
  private func imageView() -> some View {
    if let url {
      LazyImage(url: url) { state in
        if let image = state.image {
          image.resizable().aspectRatio(Constants.avatarRatio, contentMode: .fit)
        } else {
          placeholderView().overlay {
            ZStack {
              Rectangle().fill(.ultraThinMaterial)
              ProgressView()
            }
          }
        }
      }
    } else {
      placeholderView()
    }
  }

  private func placeholderView() -> some View {
    Image(systemName: Constants.avatarSymbol)
      .resizable().aspectRatio(Constants.avatarRatio, contentMode: .fit)
      .background(Constants.avatarBackground)
      .foregroundStyle(Constants.avatarForeground)
  }

  private func bottomGradientView() -> some View {
    VStack {
      Spacer()
      Color.clear.background(.ultraThinMaterial)
        .frame(height: Constants.avatarGradientHeight)
        .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
    }
  }
}

private struct CandidateInterestsView: View {
  @Binding private var dragDirection: DragDirection?
  private let interests: [Interest]

  init(dragDirection: Binding<DragDirection?>, interests: [Interest]) {
    _dragDirection = dragDirection
    self.interests = interests
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Constants.interestSpacing) {
        Spacer().frame(width: Constants.interestsEdgeWidth)
        ForEach(interests, id: \.string) { interest in
          ChipView(text: interest.string)
        }
        Spacer().frame(width: Constants.interestsEdgeWidth)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .simultaneousGesture(interestsGesture())
    .mask { edgeMaskView() }
  }
}

private extension CandidateInterestsView {
  private func interestsGesture() -> some Gesture {
    DragGesture(minimumDistance: Constants.zero)
      .onChanged { _ in dragDirection = .horizontalBlocked }
      .onEnded { _ in dragDirection = nil }
  }

  private func edgeMaskView() -> some View {
    HStack(spacing: Constants.zero) {
      LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
        .frame(width: Constants.interestsEdgeWidth)
      Rectangle().fill(.black)
      LinearGradient(colors: [.clear, .black], startPoint: .trailing, endPoint: .leading)
        .frame(width: Constants.interestsEdgeWidth)
    }
  }
}

private struct CandidateBadgeView: View {
  private let title: LocalizedStringResource

  init(title: LocalizedStringResource) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .font(.caption)
      .bold()
      .foregroundStyle(.secondary)
      .padding()
      .glassEffect(.regular, in: .rect(cornerRadius: Constants.cornerRadius))
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct CardActionsBackgroundView: View {
  var body: some View {
    Constants.background.mask {
      LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
    }
  }
}

private enum Constants {
  static let background = Color(uiColor: .secondarySystemGroupedBackground)
  static let confirmForeground = Color.white
  static let shadowColor = Color.black.opacity(0.05)
  static let dislikeColor = Color.red
  static let likeColor = Color.accentColor
  static let dislikeSymbol = "xmark"
  static let likeSymbol = "checkmark"
  static let nameBottomPadding: CGFloat = 3
  static let descriptionTopPadding: CGFloat = 5
  static let cornerRadius: CGFloat = 20
  static let shadowRadius: CGFloat = 10
  static let rotationSensitivity: CGFloat = 40
  static let dragThreshold: CGFloat = 5
  static let swipeExitDistance: CGFloat = 500
  static let swipeThreshold: CGFloat = 150
  static let overlayStartDistance: CGFloat = 100
  static let overlayFullDistance: CGFloat = 300
  static let overlayRange = overlayFullDistance - overlayStartDistance
  static let overlayColorOpacity = 0.3
  static let overlayMaterialOpacity = 0.9
  static let glassTintOpacity = 0.2
  static let cardDescriptionLineLimit = 9
  static let collapsedDescriptionLineLimit = 8
  static let expandButtonSpacing: CGFloat = 7
  static let interestSpacing: CGFloat = 5
  static let interestsEdgeWidth: CGFloat = 10
  static let zero: CGFloat = 0
  static let avatarSymbol = "person.fill"
  static let avatarRatio: CGFloat = 1
  static let avatarBackground = Color.gray
  static let avatarForeground = Color.white
  static let avatarGradientHeight: CGFloat = 100
}
