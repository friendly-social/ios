import Foundation
import NotificationDetailsApi
import SwiftUI
import Synchronization
import Testing
import UIKit
import XCTest

@MainActor @Suite(.serialized)
struct NotificationResponseStoreTests {
  @Test func recreatedSceneConsumesPendingTapAndContinuesReceiving() async throws {
    let responses = NotificationResponseStore()
    var received: [Int64] = []
    try await removeSceneConsumer(responses) { received.append($0.id) }
    await receive(.init(id: 43), into: responses)
    let pendingTap = XCTestExpectation(description: "Pending tap received by the recreated scene")
    let nextTap = XCTestExpectation(description: "Tap received by the recreated scene")
    let nextScene = try await showScene(responses) {
      received.append($0.id)
      if $0.id == 43 { pendingTap.fulfill() }
      if $0.id == 44 { nextTap.fulfill() }
    }
    defer { nextScene.isHidden = true }
    #expect(await XCTWaiter.fulfillment(of: [pendingTap], timeout: Constants.timeout) == .completed)
    #expect(received == [43])
    #expect(responses.selection == nil)
    await receive(.init(id: 44), into: responses)
    #expect(await XCTWaiter.fulfillment(of: [nextTap], timeout: Constants.timeout) == .completed)
    #expect(received == [43, 44])
  }

  @Test func backgroundResponseCompletesOnMainAndBuffersTheSelection() async {
    let responses = NotificationResponseStore()
    let calls = Mutex(0)
    await withCheckedContinuation { (finished: CheckedContinuation<Void, Never>) in
      Task.detached {
        responses.receive(NotificationSelection(id: 42)) {
          #expect(Thread.isMainThread)
          calls.withLock { $0 += 1 }
          finished.resume()
        }
      }
    }
    #expect(responses.consume()?.id == 42)
    #expect(calls.withLock { $0 } == 1)
  }

  @Test func consumesOnlyTheLatestPendingTapOnce() async {
    let responses = NotificationResponseStore()
    await receive(.init(id: 42), into: responses)
    await receive(.init(id: 43), into: responses)
    #expect(responses.consume()?.id == 43)
    #expect(responses.consume() == nil)
  }

  @Test func ignoredResponseStillCompletesOnMain() async {
    let responses = NotificationResponseStore()
    await receive(nil, into: responses)
    #expect(responses.consume() == nil)
  }

  @Test func ignoredResponseDoesNotDiscardThePendingTap() async {
    let responses = NotificationResponseStore()
    await receive(.init(id: 42), into: responses)
    await receive(nil, into: responses)
    #expect(responses.consume()?.id == 42)
  }
}

private extension NotificationResponseStoreTests {
  private func removeSceneConsumer(
    _ responses: NotificationResponseStore,
    onSelection: @escaping (NotificationSelection) -> Void
  ) async throws {
    let disappeared = XCTestExpectation(description: "Previous scene consumer disappeared")
    let window = try await showScene(
      responses,
      onDisappear: { disappeared.fulfill() },
      onSelection: onSelection
    )
    window.isHidden = true
    window.rootViewController = nil
    let result = await XCTWaiter.fulfillment(of: [disappeared], timeout: Constants.timeout)
    #expect(result == .completed)
  }

  private func receive(
    _ selection: NotificationSelection?,
    into responses: NotificationResponseStore
  ) async {
    await withCheckedContinuation { (finished: CheckedContinuation<Void, Never>) in
      Task.detached {
        responses.receive(selection) {
          #expect(Thread.isMainThread)
          finished.resume()
        }
      }
    }
  }

  private func showScene(
    _ responses: NotificationResponseStore,
    onDisappear: @escaping () -> Void = {},
    onSelection: @escaping (NotificationSelection) -> Void
  ) async throws -> UIWindow {
    let appeared = XCTestExpectation(description: "Scene consumer appeared")
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(
      rootView: NotificationSceneProbe(
        responses: responses,
        onSelection: onSelection,
        onAppear: { appeared.fulfill() },
        onDisappear: onDisappear
      )
    )
    window.isHidden = false
    #expect(await XCTWaiter.fulfillment(of: [appeared], timeout: Constants.timeout) == .completed)
    return window
  }
}

private struct NotificationSceneProbe: View {
  let responses: NotificationResponseStore
  let onSelection: (NotificationSelection) -> Void
  let onAppear: () -> Void
  let onDisappear: () -> Void

  var body: some View {
    Color.clear
      .onChange(of: responses.selection, initial: true) {
        if let selection = responses.consume() { onSelection(selection) }
      }
      .onAppear(perform: onAppear)
      .onDisappear(perform: onDisappear)
  }
}

private enum Constants {
  static let timeout: TimeInterval = 2
}
