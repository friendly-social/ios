@testable import CommunityEditorFeature
import CommunityProfileService
import Dependencies
import Foundation
import PhotosUI
import SwiftUI
import Synchronization
import Testing

@MainActor struct EditorPhotoImportTests {
  private let session = CommunitySession(accountID: 7, token: "token", sessionID: "session")

  @Test func cancelledImportStopsBeforeNextItemWithoutShowingAnError() async {
    let calls = Mutex(0)
    var service = EditorPhotoService.testValue
    service.selectionData = { _ in
      calls.withLock { $0 += 1 }
      throw CancellationError()
    }
    let model = model(service: service)
    await model.importPhotos([.init(itemIdentifier: "first"), .init(itemIdentifier: "second")])
    #expect(calls.withLock { $0 } == 1)
    #expect(model.photoError == nil)
    #expect(!model.isImporting)
    #expect(model.photoIDs().isEmpty)
  }

  @Test func cancelledTaskDoesNotPrepareAnImageReturnedByThePicker() async {
    let selection = ImportSelection()
    let preparations = Mutex(0)
    var service = EditorPhotoService.testValue
    service.selectionData = { _ in await selection.data() }
    service.restore = { _, _, _ in
      preparations.withLock { $0 += 1 }
      return .init(preview: Data())
    }
    let model = model(service: service)
    let task = Task { await model.importPhotos([.init(itemIdentifier: "fixture")]) }
    await selection.started()
    task.cancel()
    await selection.finish()
    await task.value
    #expect(preparations.withLock { $0 } == 0)
    #expect(model.photoError == nil)
    #expect(!model.isImporting)
    #expect(model.photoIDs().isEmpty)
  }
}

private extension EditorPhotoImportTests {
  private func model(service: EditorPhotoService) -> CommunityEditorViewModel {
    let model = withDependencies { $0[EditorPhotoService.self] = service } operation: {
      CommunityEditorViewModel()
    }
    model.start(session: session)
    return model
  }
}

private actor ImportSelection {
  private var completion: CheckedContinuation<Data, Never>?
  private var start: CheckedContinuation<Void, Never>?

  func data() async -> Data {
    await withCheckedContinuation {
      completion = $0
      start?.resume()
      start = nil
    }
  }

  func started() async {
    guard completion == nil else { return }
    await withCheckedContinuation { start = $0 }
  }

  func finish() {
    completion?.resume(returning: Data())
    completion = nil
  }
}
