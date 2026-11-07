import SwiftUI

public struct PhotoViewer: View {
  private let image: Image
  private let imageLabel: Text
  private let sourceFrame: CGRect
  private let imageSize: CGSize?
  private let sourceCornerRadius: CGFloat

  public init(
    image: Image,
    imageLabel: Text,
    sourceFrame: CGRect,
    imageSize: CGSize? = nil,
    sourceCornerRadius: CGFloat = 0
  ) {
    self.image = image
    self.imageLabel = imageLabel
    self.sourceFrame = sourceFrame
    self.imageSize = imageSize
    self.sourceCornerRadius = sourceCornerRadius
  }
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var viewModel = PhotoViewerModel()
  @State private var isExpanded = false
  @State private var isClosing = false

  public var body: some View { contentView() }
}

private extension PhotoViewer {
  private var settleAnimation: Animation? {
    reduceMotion ? nil : .spring(response: Constants.springResponse, dampingFraction: Constants.springDamping)
  }

  private var presentationAnimation: Animation? {
    guard !reduceMotion else { return nil }
    if sourceCornerRadius > Constants.zero {
      return .easeInOut(duration: Constants.avatarTransitionDuration)
    }
    return settleAnimation
  }

  private func contentView() -> some View {
    GeometryReader { geometry in
      photoView(in: geometry)
        .onChange(of: geometry.size, initial: true) { updateGeometry(geometry.size) }
    }
    .ignoresSafeArea()
    .background(Constants.background.opacity(isExpanded ? viewModel.backgroundOpacity : Constants.hidden).ignoresSafeArea())
    .overlay(alignment: .topLeading) { closeButton() }
    .statusBarHidden()
    .preferredColorScheme(.dark)
    .presentationBackground(.clear)
    .interactiveDismissDisabled()
    .sensoryFeedback(.impact(weight: .light), trigger: viewModel.feedbackTrigger)
    .task { await openPhoto() }
    .transaction { $0.disablesAnimations = false }
  }

  private func photoView(in geometry: GeometryProxy) -> some View {
    let viewport = geometry.size
    let size = fittedSize(in: viewport)
    let origin = geometry.frame(in: .global).origin
    let position = isExpanded
      ? CGPoint(x: viewport.width / Constants.halfDivisor + viewModel.displayOffset.width,
                y: viewport.height / Constants.halfDivisor + viewModel.displayOffset.height)
      : CGPoint(x: sourceFrame.midX - origin.x, y: sourceFrame.midY - origin.y)
    return PhotoTransitionImage(
      image: image,
      size: isExpanded ? size : sourceFrame.size,
      cornerRadius: isExpanded ? Constants.zero : sourceCornerRadius,
      fillsSource: sourceCornerRadius > Constants.zero)
      .scaleEffect(isExpanded ? viewModel.displayScale : Constants.unitScale)
      .position(position)
      .frame(width: viewport.width, height: viewport.height)
      .clipped()
      .contentShape(.rect)
      .gesture(zoomGesture(in: viewport))
      .simultaneousGesture(panGesture())
      .gesture(tapGesture())
      .allowsHitTesting(!isClosing)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(imageLabel)
      .accessibilityAddTraits(.isImage)
      .accessibilityAction(named: .photoViewerToggleZoom) {
        withAnimation(settleAnimation) {
          viewModel.doubleTapped(at: CGPoint(x: viewport.width / Constants.halfDivisor, y: viewport.height / Constants.halfDivisor))
        }
      }
      .accessibilityAction(.escape) { closePhoto() }
  }

  private func closeButton() -> some View {
    Button(.photoViewerClose, systemImage: Constants.close) { closePhoto() }
      .labelStyle(.iconOnly)
      .frame(width: Constants.touchTarget, height: Constants.touchTarget)
      .buttonStyle(.glass)
      .buttonBorderShape(.circle)
      .controlSize(.large)
      .padding(Constants.padding)
      .opacity(viewModel.showsControls && isExpanded ? Constants.visible : Constants.hidden)
      .allowsHitTesting(viewModel.showsControls && !isClosing)
      .accessibilityHidden(!viewModel.showsControls)
  }

  private func zoomGesture(in viewport: CGSize) -> some Gesture {
    MagnifyGesture()
      .onChanged { value in
        viewModel.pinchChanged(
          magnification: value.magnification,
          anchor: CGPoint(x: value.startAnchor.x * viewport.width, y: value.startAnchor.y * viewport.height)
        )
      }
      .onEnded { _ in withAnimation(settleAnimation) { viewModel.pinchEnded() } }
  }

  private func panGesture() -> some Gesture {
    DragGesture()
      .onChanged { viewModel.dragChanged(translation: $0.translation) }
      .onEnded { value in
        let shouldDismiss = withAnimation(settleAnimation) {
          viewModel.dragEnded(predictedTranslation: value.predictedEndTranslation)
        }
        if shouldDismiss { closePhoto() }
      }
  }

  private func tapGesture() -> some Gesture {
    SpatialTapGesture(count: Constants.doubleTapCount)
      .exclusively(before: SpatialTapGesture())
      .onEnded { value in
        withAnimation(settleAnimation) {
          switch value {
          case let .first(tap): viewModel.doubleTapped(at: tap.location)
          case .second: viewModel.singleTapped()
          }
        }
      }
  }

  private func updateGeometry(_ viewport: CGSize) {
    viewModel.geometryChanged(viewport: viewport, imageSize: fittedSize(in: viewport))
  }

  private func fittedSize(in viewport: CGSize) -> CGSize {
    let size = imageSize ?? sourceFrame.size
    guard size.width > Constants.zero, size.height > Constants.zero else { return viewport }
    let factor = min(viewport.width / size.width, viewport.height / size.height)
    return CGSize(width: size.width * factor, height: size.height * factor)
  }

  private func openPhoto() async {
    // Commit the source frame before starting the only transition in this presentation.
    try? await Task.sleep(for: Constants.presentationDelay)
    guard !Task.isCancelled, !isClosing else { return }
    withAnimation(presentationAnimation) {
      isExpanded = true
    }
  }

  private func closePhoto() {
    guard !isClosing else { return }
    isClosing = true
    withAnimation(presentationAnimation, completionCriteria: .removed) {
      isExpanded = false
    } completion: {
      var transaction = Transaction(animation: nil)
      transaction.disablesAnimations = true
      withTransaction(transaction) { dismiss() }
    }
  }
}

private enum Constants {
  static let presentationDelay = Duration.milliseconds(20)
  static let unitScale: CGFloat = 1
  static let zero: CGFloat = 0
  static let doubleTapCount = 2
  static let halfDivisor: CGFloat = 2
  static let touchTarget: CGFloat = 44
  static let padding: CGFloat = 16
  static let springResponse: Double = 0.32
  static let springDamping: Double = 0.82
  static let avatarTransitionDuration: Double = 0.28
  static let visible: Double = 1
  static let hidden: Double = 0
  static let background = Color.black
  static let close = "xmark"
}
