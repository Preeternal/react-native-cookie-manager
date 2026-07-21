import Foundation
import XCTest
@testable import CookieHeaderLogic

final class CookieHeaderLogicTests: XCTestCase {
  func testFormatsDuplicateNamesWithoutCollapsingThem() {
    let cookies = [
      makeCookie(name: "session", value: "root", domain: "example.com", path: "/"),
      makeCookie(name: "session", value: "account", domain: "example.com", path: "/account"),
    ]

    let header = CookieHeaderLogic.headerValue(for: cookies)

    XCTAssertTrue(header.contains("session=root"))
    XCTAssertTrue(header.contains("session=account"))
  }

  func testReturnsEmptyValueWhenThereAreNoCookies() {
    XCTAssertEqual(CookieHeaderLogic.headerValue(for: []), "")
  }

  func testWebKitMatchingAppliesDomainPathSecureAndExpiryRules() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let cookies = [
      makeCookie(name: "root", domain: "example.com", path: "/"),
      makeCookie(name: "account", domain: "example.com", path: "/account", secure: true),
      makeCookie(name: "admin", domain: "example.com", path: "/admin"),
      makeCookie(
        name: "expired",
        domain: "example.com",
        path: "/",
        expires: now.addingTimeInterval(-1)
      ),
      makeCookie(name: "other", domain: "other.example", path: "/"),
    ]

    let result = CookieHeaderLogic.matchingWebKitCookies(
      for: URL(string: "https://example.com/account/profile")!,
      from: cookies,
      now: now
    )

    XCTAssertEqual(result.map(\.name), ["account", "root"])
  }

  func testSecureCookieIsExcludedFromInsecureRequest() {
    let cookies = [
      makeCookie(name: "plain", domain: "example.com", path: "/"),
      makeCookie(name: "secure", domain: "example.com", path: "/", secure: true),
    ]

    let result = CookieHeaderLogic.matchingWebKitCookies(
      for: URL(string: "http://example.com/")!,
      from: cookies
    )

    XCTAssertEqual(result.map(\.name), ["plain"])
  }

  func testHostOnlyCookieDoesNotMatchSubdomainButDomainCookieDoes() {
    let cookies = [
      makeCookie(name: "hostOnly", domain: "example.com", path: "/"),
      makeCookie(name: "domain", domain: ".example.com", path: "/"),
    ]

    let result = CookieHeaderLogic.matchingWebKitCookies(
      for: URL(string: "https://api.example.com/")!,
      from: cookies
    )

    XCTAssertEqual(result.map(\.name), ["domain"])
  }

  func testCookiePathRequiresDirectoryBoundary() {
    let cookie = makeCookie(name: "api", domain: "example.com", path: "/api")

    let matching = CookieHeaderLogic.matchingWebKitCookies(
      for: URL(string: "https://example.com/api/users")!,
      from: [cookie]
    )
    let nonMatching = CookieHeaderLogic.matchingWebKitCookies(
      for: URL(string: "https://example.com/apiv2")!,
      from: [cookie]
    )

    XCTAssertEqual(matching.map(\.name), ["api"])
    XCTAssertTrue(nonMatching.isEmpty)
  }

  private func makeCookie(
    name: String,
    value: String = "value",
    domain: String,
    path: String,
    secure: Bool = false,
    expires: Date? = nil
  ) -> HTTPCookie {
    var properties: [HTTPCookiePropertyKey: Any] = [
      .name: name,
      .value: value,
      .domain: domain,
      .path: path,
    ]
    if secure {
      properties[.secure] = true
    }
    if let expires {
      properties[.expires] = expires
    }
    return HTTPCookie(properties: properties)!
  }
}
