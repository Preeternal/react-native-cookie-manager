import XCTest
@testable import CookieCollectionLogic

final class CookieCollectionLogicTests: XCTestCase {
  private struct CookieFixture {
    let name: String
    let path: String
  }

  private let cookies = [
    CookieFixture(name: "session", path: "/"),
    CookieFixture(name: "session", path: "/account"),
  ]

  func testArrayPreservesCookiesWithDuplicateNames() {
    let result = CookieCollectionLogic.asArray(cookies) { cookie in
      ["name": cookie.name, "path": cookie.path]
    }

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0]["path"] as? String, "/")
    XCTAssertEqual(result[1]["path"] as? String, "/account")
  }

  func testDictionaryRetainsLegacyLastCookieWinsBehavior() {
    let result = CookieCollectionLogic.asDictionary(
      cookies,
      name: { $0.name },
      transform: { cookie in ["name": cookie.name, "path": cookie.path] }
    )

    XCTAssertEqual(result.count, 1)
    let session = result["session"] as? [String: String]
    XCTAssertEqual(session?["path"], "/account")
  }
}
