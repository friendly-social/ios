@testable import CommunityMarkdownFeature
import Foundation
import SwiftUI
import Testing
import UIKit

@MainActor struct MarkdownPreviewLayoutTests {
  @Test(arguments: [
    ("![](file:///fixture.jpg)\nCaption", "![](file:///fixture.jpg)Caption"),
    ("Caption\n![](file:///fixture.jpg)", "Caption![](file:///fixture.jpg)"),
    ("![](file:///first.jpg)\n![](file:///second.jpg)", "![](file:///first.jpg)![](file:///second.jpg)"),
  ])
  func imageLineBreakDoesNotCreateAnEmptyTextRow(source: String, equivalent: String) {
    #expect(height(source) == height(equivalent))
  }

  @Test func separateParagraphKeepsMoreSpaceThanAnImageLineBreak() {
    let singleLineBreak = height("![](file:///fixture.jpg)\nCaption")
    let separateParagraph = height("![](file:///fixture.jpg)\n\nCaption")
    #expect(separateParagraph > singleLineBreak)
  }
}

private extension MarkdownPreviewLayoutTests {
  private func height(_ source: String) -> CGFloat {
    let controller = UIHostingController(rootView: MarkdownPreview(source: source))
    return controller.sizeThatFits(in: CGSize(width: 300, height: 1000)).height
  }
}
