import XCTest
import WebKit
@testable import CookieChangeObserver

final class CookieChangeObserverTests: XCTestCase {
  func testRepeatedStartUsesOneBackendObservationAndLatestHandler() {
    var startCount = 0
    var stopCount = 0
    var backendHandler: CookieChangeObservationLifecycle.Handler?
    var receivedByFirst: [CookieChangeStore] = []
    var receivedBySecond: [CookieChangeStore] = []

    let lifecycle = CookieChangeObservationLifecycle(
      startObservation: { handler in
        startCount += 1
        backendHandler = handler
      },
      stopObservation: {
        stopCount += 1
      }
    )

    lifecycle.start { receivedByFirst.append($0) }
    lifecycle.start { receivedBySecond.append($0) }
    backendHandler?(.webKit)

    XCTAssertTrue(lifecycle.isObserving)
    XCTAssertEqual(startCount, 1)
    XCTAssertEqual(stopCount, 0)
    XCTAssertEqual(receivedByFirst, [])
    XCTAssertEqual(receivedBySecond, [.webKit])
  }

  func testStopIsIdempotentAndAllowsACleanRestart() {
    var startCount = 0
    var stopCount = 0

    let lifecycle = CookieChangeObservationLifecycle(
      startObservation: { _ in startCount += 1 },
      stopObservation: { stopCount += 1 }
    )

    lifecycle.start { _ in }
    lifecycle.stop()
    lifecycle.stop()
    lifecycle.start { _ in }
    lifecycle.stop()

    XCTAssertFalse(lifecycle.isObserving)
    XCTAssertEqual(startCount, 2)
    XCTAssertEqual(stopCount, 2)
  }

  func testFoundationMutationEmitsFoundationInvalidation() throws {
    let observer = CookieChangeObserver()
    let event = expectation(description: "Foundation cookie change")
    let cookie = try makeCookie(name: "foundation-\(UUID().uuidString)")

    observer.start { store in
      if store == .foundation {
        event.fulfill()
      }
    }
    DispatchQueue.main.async {
      HTTPCookieStorage.shared.setCookie(cookie)
    }

    wait(for: [event], timeout: 5)
    observer.stop()
    HTTPCookieStorage.shared.deleteCookie(cookie)
  }

  func testWebKitMutationEmitsWebKitInvalidation() throws {
    let observer = CookieChangeObserver()
    let event = expectation(description: "WebKit cookie change")
    let mutation = expectation(description: "WebKit mutation")
    let cleanup = expectation(description: "WebKit cleanup")
    let cookie = try makeCookie(name: "webkit-\(UUID().uuidString)")
    let store = WKWebsiteDataStore.default().httpCookieStore

    observer.start { changedStore in
      if changedStore == .webKit {
        event.fulfill()
      }
    }
    DispatchQueue.main.async {
      store.setCookie(cookie) { mutation.fulfill() }
    }

    wait(for: [mutation, event], timeout: 5)
    observer.stop()
    store.delete(cookie) { cleanup.fulfill() }
    wait(for: [cleanup], timeout: 5)
  }

  private func makeCookie(name: String) throws -> HTTPCookie {
    try XCTUnwrap(
      HTTPCookie(properties: [
        .name: name,
        .value: "1",
        .domain: "cookie-change.example",
        .path: "/",
      ])
    )
  }
}
