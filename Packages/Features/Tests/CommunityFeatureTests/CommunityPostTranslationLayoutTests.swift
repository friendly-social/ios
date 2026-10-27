@testable import CommunityFeature
import CommunityMarkdownService
import CommunityService
import CustomDump
import Dependencies
import Foundation
import PostTranslationService
import SwiftUI
import Testing
import UIKit

@MainActor
struct CommunityPostTranslationLayoutTests {
  @Test(arguments: [DynamicTypeSize.large, .accessibility1, .accessibility3])
  func loadingDoesNotChangeHeaderHeight(size: DynamicTypeSize) async {
    let model = await makeModel(translated: false)
    let normal = height(model, size: size)
    await model.cycleLanguage()
    expectNoDifference(height(model, size: size), normal)
  }

  @Test(arguments: [ColorScheme.light, .dark], [DynamicTypeSize.large, .accessibility3])
  func rendersLanguageButtonsAndUnknownLanguage(scheme: ColorScheme, size: DynamicTypeSize) async throws {
    let original = await makeModel(translated: false)
    let translated = await makeModel(translated: true)
    let unknown = await makeModel(translated: false, languages: [], source: "OK")
    for locale in ["en", "ru"] {
      let view = preview(original: original, translated: translated, unknown: unknown)
        .environment(\.colorScheme, scheme)
        .environment(\.dynamicTypeSize, size)
        .environment(\.locale, Locale(identifier: locale))
      let image = try snapshot(view)
      Attachment.record(image, named: "post-translation-\(locale)-\(scheme)-\(size).png")
      expectNoDifference(image.size.width, Constants.width)
    }
  }
}

private extension CommunityPostTranslationLayoutTests {
  private func preview(
    original: CommunityPostTranslationViewModel, translated: CommunityPostTranslationViewModel,
    unknown: CommunityPostTranslationViewModel
  ) -> some View {
    VStack(alignment: .leading, spacing: Constants.spacing) {
      Text("Hello world. This post can be translated on your iPhone.")
      header(original)
      Divider()
      Text("Привет, мир. Этот пост можно перевести на вашем iPhone.")
      header(translated)
      Divider()
      Text("OK")
      header(unknown)
    }
    .padding(Constants.padding)
    .frame(width: Constants.width)
    .background(Color(uiColor: .systemBackground))
  }

  private func snapshot(_ view: some View) throws -> UIImage {
    let controller = UIHostingController(rootView: view)
    controller.safeAreaRegions = []
    let size = controller.sizeThatFits(in: CGSize(width: Constants.width, height: Constants.maximumHeight))
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(origin: .zero, size: size)
    window.rootViewController = controller
    window.isHidden = false
    controller.view.frame = CGRect(origin: .zero, size: size)
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: Constants.renderDelay))
    controller.view.frame = CGRect(origin: .zero, size: size)
    controller.view.layoutIfNeeded()
    let format = UIGraphicsImageRendererFormat()
    format.scale = Constants.scale
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
      controller.view.layer.render(in: context.cgContext)
    }
    window.isHidden = true
    return image
  }

  private func makeModel(
    translated: Bool, languages: Set<PostTranslationLanguage> = [.english], source: String = "Hello world"
  ) async -> CommunityPostTranslationViewModel {
    let model = withDependencies {
      $0.uuid = .incrementing
      $0[PostTranslationService.self] = PostTranslationService(load: { _ in
        .init(detectedLanguages: languages, translations: translated ? [.russian: [AttributedString("Привет мир")]] : [:],
              selection: translated ? .translated(.russian) : .original)
      }, translate: { _, _ in throw PostTranslationError.unavailable }, selectVersion: { _, _ in })
      $0[CommunityFeedPreparationService.self] = .fixture
    } operation: { CommunityPostTranslationViewModel() }
    await model.load(.init(source: source, document: try? MarkdownDocument(source: source)))
    return model
  }

  private func header(_ model: CommunityPostTranslationViewModel) -> some View {
    let post = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 1, accessHash: "fixture"), text: "Hello world",
      owner: .init(id: 8, accessHash: "fixture", nickname: "Author"), date: .now))
    return CommunityPostHeader(
      post: post, openAuthor: nil, canManage: false, isDeleting: false,
      actionsDisabled: false, edit: {}, delete: {}, translation: model)
  }

  private func height(_ model: CommunityPostTranslationViewModel, size: DynamicTypeSize) -> CGFloat {
    let view = header(model).environment(\.dynamicTypeSize, size)
    return UIHostingController(rootView: view)
      .sizeThatFits(in: CGSize(width: Constants.width, height: Constants.maximumHeight)).height
  }
}

private enum Constants {
  static let width: CGFloat = 310
  static let maximumHeight: CGFloat = 2000
  static let spacing: CGFloat = 12
  static let padding: CGFloat = 16
  static let scale: CGFloat = 2
  static let renderDelay: TimeInterval = 0.05
}
