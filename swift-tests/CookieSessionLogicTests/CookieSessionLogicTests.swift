import XCTest
@testable import CookieSessionLogic

final class CookieSessionLogicTests: XCTestCase {
  func testFoundationOnlyDoesNotLoadOrDeleteWebKitCookies() {
    let foundationSessionCookie = makeCookie(name: "foundation-session")
    let webKitSessionCookie = makeCookie(name: "webkit-session")
    var deletedFoundationNames: [String] = []
    var webKitLoaded = false
    var deletedWebKitNames: [String] = []
    var result: Bool?

    CookieSessionLogic.removeSessionCookies(
      foundationCookies: [foundationSessionCookie],
      clearFoundation: true,
      clearWebKit: false,
      deleteFoundation: { cookie in
        deletedFoundationNames.append(cookie.name)
      },
      loadWebKitCookies: { completion in
        webKitLoaded = true
        completion([webKitSessionCookie])
      },
      deleteWebKitCookie: { cookie, completion in
        deletedWebKitNames.append(cookie.name)
        completion()
      }
    ) { removed in
      result = removed
    }

    XCTAssertEqual(deletedFoundationNames, ["foundation-session"])
    XCTAssertFalse(webKitLoaded)
    XCTAssertTrue(deletedWebKitNames.isEmpty)
    XCTAssertEqual(result, true)
  }

  func testWebKitOnlyKeepsFoundationCookies() {
    let foundationSessionCookie = makeCookie(name: "foundation-session")
    let webKitSessionCookie = makeCookie(name: "webkit-session")
    var deletedFoundationNames: [String] = []
    var deletedWebKitNames: [String] = []
    var result: Bool?
    let completionExpectation = expectation(description: "WebKit cookies removed")

    CookieSessionLogic.removeSessionCookies(
      foundationCookies: [foundationSessionCookie],
      clearFoundation: false,
      clearWebKit: true,
      deleteFoundation: { cookie in
        deletedFoundationNames.append(cookie.name)
      },
      loadWebKitCookies: { completion in
        completion([webKitSessionCookie])
      },
      deleteWebKitCookie: { cookie, completion in
        deletedWebKitNames.append(cookie.name)
        completion()
      }
    ) { removed in
      result = removed
      completionExpectation.fulfill()
    }

    wait(for: [completionExpectation], timeout: 1)
    XCTAssertTrue(deletedFoundationNames.isEmpty)
    XCTAssertEqual(deletedWebKitNames, ["webkit-session"])
    XCTAssertEqual(result, true)
  }

  func testBothStoresDeleteSessionCookiesAndKeepPersistentCookies() {
    let foundationSessionCookie = makeCookie(name: "foundation-session")
    let foundationPersistentCookie = makeCookie(
      name: "foundation-persistent",
      expires: Date(timeIntervalSinceNow: 3_600)
    )
    let webKitSessionCookie = makeCookie(name: "webkit-session")
    let webKitPersistentCookie = makeCookie(
      name: "webkit-persistent",
      expires: Date(timeIntervalSinceNow: 3_600)
    )
    var deletedFoundationNames: [String] = []
    var deletedWebKitNames: [String] = []
    var result: Bool?
    let completionExpectation = expectation(description: "both stores cleared")

    CookieSessionLogic.removeSessionCookies(
      foundationCookies: [foundationSessionCookie, foundationPersistentCookie],
      clearFoundation: true,
      clearWebKit: true,
      deleteFoundation: { cookie in
        deletedFoundationNames.append(cookie.name)
      },
      loadWebKitCookies: { completion in
        completion([webKitSessionCookie, webKitPersistentCookie])
      },
      deleteWebKitCookie: { cookie, completion in
        deletedWebKitNames.append(cookie.name)
        completion()
      }
    ) { removed in
      result = removed
      completionExpectation.fulfill()
    }

    wait(for: [completionExpectation], timeout: 1)
    XCTAssertEqual(deletedFoundationNames, ["foundation-session"])
    XCTAssertEqual(deletedWebKitNames, ["webkit-session"])
    XCTAssertEqual(result, true)
  }

  func testRemoveSessionCookiesKeepsPersistentCookiesAndWaitsForEveryDeletion() {
    let firstSessionCookie = makeCookie(name: "first-session")
    let persistentCookie = makeCookie(
      name: "persistent",
      expires: Date(timeIntervalSinceNow: 3_600)
    )
    let secondSessionCookie = makeCookie(name: "second-session")
    var deletedNames: [String] = []
    var deletionCompletions: [() -> Void] = []
    var result: Bool?
    let completionExpectation = expectation(description: "all session cookies removed")

    CookieSessionLogic.removeSessionCookies(
      from: [firstSessionCookie, persistentCookie, secondSessionCookie],
      delete: { cookie, completion in
        deletedNames.append(cookie.name)
        deletionCompletions.append(completion)
      }
    ) { removed in
      result = removed
      completionExpectation.fulfill()
    }

    XCTAssertEqual(deletedNames, ["first-session", "second-session"])
    XCTAssertEqual(deletionCompletions.count, 2)
    XCTAssertNil(result)

    deletionCompletions.removeFirst()()
    XCTAssertNil(result)

    deletionCompletions.removeFirst()()
    wait(for: [completionExpectation], timeout: 1)
    XCTAssertEqual(result, true)
  }

  func testRemoveSessionCookiesReturnsFalseWithoutDeletingPersistentCookies() {
    let persistentCookie = makeCookie(
      name: "persistent",
      expires: Date(timeIntervalSinceNow: 3_600)
    )
    var deleteCalled = false
    var result: Bool?

    CookieSessionLogic.removeSessionCookies(
      from: [persistentCookie],
      delete: { _, _ in
        deleteCalled = true
      }
    ) { removed in
      result = removed
    }

    XCTAssertFalse(deleteCalled)
    XCTAssertEqual(result, false)
  }

  private func makeCookie(name: String, expires: Date? = nil) -> HTTPCookie {
    var properties: [HTTPCookiePropertyKey: Any] = [
      .domain: "example.com",
      .path: "/",
      .name: name,
      .value: "value",
    ]
    properties[.expires] = expires

    return HTTPCookie(properties: properties)!
  }
}
