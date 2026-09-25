import Foundation
import Observation

@MainActor @Observable
final class MarkdownPhotoViewModel {
  private(set) var scale = Constants.minimumScale
  private(set) var offset = CGSize.zero
  private(set) var dismissalOffset = CGSize.zero
  private(set) var feedbackTrigger = 0
  private(set) var showsControls = true
  private var viewport = CGSize.zero
  private var imageSize = CGSize.zero
  private var pinchStart: (scale: CGFloat, offset: CGSize)?
  private var dragStart: CGSize?
  private var dismissalDrag = false
  private var didSignalDismissal = false

  var dismissalProgress: CGFloat {
    min(Constants.minimumScale, abs(dismissalOffset.height) / Constants.dismissDistance)
  }

  var displayScale: CGFloat { scale * (Constants.minimumScale - dismissalProgress * Constants.dismissShrink) }
  var backgroundOpacity: Double { Double(Constants.minimumScale - dismissalProgress * Constants.backgroundFade) }
  var displayOffset: CGSize {
    CGSize(width: offset.width + dismissalOffset.width, height: offset.height + dismissalOffset.height)
  }

  func geometryChanged(viewport: CGSize, imageSize: CGSize) {
    self.viewport = viewport
    self.imageSize = imageSize
    offset = clamped(offset, scale: scale)
  }

  func pinchChanged(magnification: CGFloat, anchor: CGPoint) {
    if pinchStart == nil {
      pinchStart = (scale, offset)
      dismissalOffset = .zero
      dismissalDrag = false
      dragStart = nil
    }
    guard let start = pinchStart else { return }
    scale = resistedScale(start.scale * magnification)
    let ratio = scale / start.scale
    let point = centered(anchor)
    offset = CGSize(
      width: point.x - (point.x - start.offset.width) * ratio,
      height: point.y - (point.y - start.offset.height) * ratio
    )
  }

  func pinchEnded() {
    guard pinchStart != nil else { return }
    if scale < Constants.minimumScale { feedbackTrigger += 1 }
    scale = min(Constants.maximumScale, max(Constants.minimumScale, scale))
    offset = clamped(offset, scale: scale)
    pinchStart = nil
  }

  func doubleTapped(at point: CGPoint) {
    if scale > Constants.minimumScale {
      scale = Constants.minimumScale
      offset = .zero
    } else {
      scale = Constants.doubleTapScale
      let point = centered(point)
      offset = clamped(
        CGSize(width: point.x * (Constants.minimumScale - scale), height: point.y * (Constants.minimumScale - scale)),
        scale: scale
      )
    }
    feedbackTrigger += 1
  }

  func dragChanged(translation: CGSize) {
    guard pinchStart == nil else { return }
    if dragStart == nil {
      dragStart = offset
      dismissalDrag = scale <= Constants.minimumScale && abs(translation.height) > abs(translation.width)
      didSignalDismissal = false
    }
    if dismissalDrag {
      dismissalOffset = translation
      if dismissalProgress >= Constants.minimumScale && !didSignalDismissal {
        feedbackTrigger += 1
        didSignalDismissal = true
      }
    } else if let start = dragStart {
      offset = clamped(CGSize(width: start.width + translation.width, height: start.height + translation.height), scale: scale)
    }
  }

  func dragEnded(predictedTranslation: CGSize) -> Bool {
    defer {
      dragStart = nil
      dismissalDrag = false
      didSignalDismissal = false
    }
    guard pinchStart == nil else { return false }
    let shouldDismiss = dismissalDrag && (
      abs(dismissalOffset.height) >= Constants.dismissDistance
        || (abs(dismissalOffset.height) >= Constants.flickDistance
          && abs(predictedTranslation.height) >= Constants.dismissDistance)
    )
    if shouldDismiss {
      if !didSignalDismissal { feedbackTrigger += 1 }
    } else {
      dismissalOffset = .zero
      offset = clamped(offset, scale: scale)
    }
    return shouldDismiss
  }

  func singleTapped() { showsControls.toggle() }
}

private extension MarkdownPhotoViewModel {
  private func centered(_ point: CGPoint) -> CGPoint {
    CGPoint(x: point.x - viewport.width / Constants.halfDivisor, y: point.y - viewport.height / Constants.halfDivisor)
  }

  private func clamped(_ value: CGSize, scale: CGFloat) -> CGSize {
    let horizontal = max(Constants.zero, (imageSize.width * scale - viewport.width) / Constants.halfDivisor)
    let vertical = max(Constants.zero, (imageSize.height * scale - viewport.height) / Constants.halfDivisor)
    return CGSize(width: min(horizontal, max(-horizontal, value.width)), height: min(vertical, max(-vertical, value.height)))
  }

  private func resistedScale(_ value: CGFloat) -> CGFloat {
    if value < Constants.minimumScale {
      return Constants.minimumScale / (Constants.minimumScale + (Constants.minimumScale - value) * Constants.resistance)
    }
    if value > Constants.maximumScale {
      return Constants.maximumScale + (value - Constants.maximumScale) * Constants.overshootResistance
    }
    return value
  }
}

private enum Constants {
  static let minimumScale: CGFloat = 1
  static let maximumScale: CGFloat = 5
  static let doubleTapScale: CGFloat = 3
  static let halfDivisor: CGFloat = 2
  static let zero: CGFloat = 0
  static let resistance: CGFloat = 0.7
  static let overshootResistance: CGFloat = 0.15
  static let dismissDistance: CGFloat = 140
  static let flickDistance: CGFloat = 35
  static let dismissShrink: CGFloat = 0.2
  static let backgroundFade: CGFloat = 0.8
}
