@testable import CommunityMarkdownFeature
import Foundation
import Testing

@MainActor
struct MarkdownPhotoViewerTests {
  @Test func pinchPreservesFocalPointAndSpringsBackFromUndershoot() {
    let model = makeModel()
    model.pinchChanged(magnification: 2, anchor: CGPoint(x: 300, y: 400))
    #expect(model.scale == 2)
    #expect(model.offset.width == -100)
    model.pinchEnded()
    model.pinchChanged(magnification: 0.2, anchor: CGPoint(x: 200, y: 400))
    #expect(model.scale < 1)
    model.pinchEnded()
    #expect(model.scale == 1)
    #expect(model.offset == .zero)
    #expect(model.feedbackTrigger == 1)
  }

  @Test func shortDragCancelsWithoutHaptic() {
    let model = makeModel()
    model.dragChanged(translation: CGSize(width: 5, height: 30))
    #expect(model.backgroundOpacity < 1)
    #expect(!model.dragEnded(predictedTranslation: CGSize(width: 5, height: 30)))
    #expect(model.dismissalOffset == .zero)
    #expect(model.feedbackTrigger == 0)
  }

  @Test func dismissalThresholdSignalsOnlyOncePerGesture() {
    let model = makeModel()
    model.dragChanged(translation: CGSize(width: 0, height: 150))
    model.dragChanged(translation: CGSize(width: 0, height: 170))
    model.dragChanged(translation: CGSize(width: 0, height: 120))
    model.dragChanged(translation: CGSize(width: 0, height: 160))
    #expect(model.feedbackTrigger == 1)
    #expect(model.dragEnded(predictedTranslation: CGSize(width: 0, height: 200)))
    #expect(model.feedbackTrigger == 1)
  }

  @Test func zoomedDragPansInsteadOfDismissing() {
    let model = makeModel()
    model.doubleTapped(at: CGPoint(x: 200, y: 400))
    model.dragChanged(translation: CGSize(width: 900, height: 900))
    #expect(!model.dragEnded(predictedTranslation: CGSize(width: 900, height: 900)))
    #expect(model.offset == CGSize(width: 400, height: 50))
    #expect(model.dismissalOffset == .zero)
  }

  @Test func doubleTapResetsScaleAndOffset() {
    let model = makeModel()
    model.doubleTapped(at: CGPoint(x: 300, y: 400))
    #expect(model.scale == 3)
    #expect(model.offset.width == -200)
    model.doubleTapped(at: CGPoint(x: 300, y: 400))
    #expect(model.scale == 1)
    #expect(model.offset == .zero)
  }
}

private extension MarkdownPhotoViewerTests {
  private func makeModel() -> MarkdownPhotoViewModel {
    let model = MarkdownPhotoViewModel()
    model.geometryChanged(viewport: CGSize(width: 400, height: 800), imageSize: CGSize(width: 400, height: 300))
    return model
  }
}
