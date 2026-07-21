import XCTest
@testable import CookieStoreClearLogic

final class CookieStoreClearLogicTests: XCTestCase {
  func testClearAllStoresWaitsForWebKitAfterClearingFoundation() {
    var events: [String] = []
    var webKitCompletion: (() -> Void)?

    CookieStoreClearLogic.clearAllStores(
      clearFoundation: {
        events.append("foundation")
      },
      clearWebKit: { completion in
        events.append("webKitStarted")
        webKitCompletion = completion
      },
      completion: {
        events.append("completed")
      }
    )

    XCTAssertEqual(events, ["foundation", "webKitStarted"])
    XCTAssertNotNil(webKitCompletion)

    webKitCompletion?()
    XCTAssertEqual(events, ["foundation", "webKitStarted", "completed"])
  }
}
