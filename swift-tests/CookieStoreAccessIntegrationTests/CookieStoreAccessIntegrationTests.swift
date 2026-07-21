import Foundation
import XCTest
@testable import CookieStoreAccess

final class CookieStoreAccessIntegrationTests: XCTestCase {
  func testFoundationRoundTripPreservesDuplicateNamesAndWaitsForDeletion() async {
    await assertRoundTrip(in: .foundation)
  }

  func testWebKitRoundTripPreservesDuplicateNamesAndWaitsForDeletion() async {
    await assertRoundTrip(in: .webKit)
  }

  func testClearAllTargetsSelectedStoreAndWaitsForCompletion() async {
    let identifier = UUID().uuidString.lowercased()
    let name = "cookie_manager_\(identifier.replacingOccurrences(of: "-", with: ""))"
    let host = "\(identifier).cookie-manager.invalid"
    let url = URL(string: "https://\(host)/")!

    await set(
      makeCookie(name: name, value: "foundation", domain: host, path: "/"),
      in: .foundation
    )
    await set(
      makeCookie(name: name, value: "webKit", domain: host, path: "/"),
      in: .webKit
    )

    await clearAll(from: .foundation)
    let foundationAfterClear = await load(for: url, from: .foundation)
    let webKitBeforeClear = await load(for: url, from: .webKit)
    XCTAssertTrue(foundationAfterClear.filter { $0.name == name }.isEmpty)
    XCTAssertEqual(webKitBeforeClear.first { $0.name == name }?.value, "webKit")

    await clearAll(from: .webKit)
    let webKitAfterClear = await load(for: url, from: .webKit)
    XCTAssertTrue(webKitAfterClear.filter { $0.name == name }.isEmpty)
  }

  private func assertRoundTrip(in store: CookieStoreKind) async {
    let identifier = UUID().uuidString.lowercased()
    let name = "cookie_manager_\(identifier.replacingOccurrences(of: "-", with: ""))"
    let host = "\(identifier).cookie-manager.invalid"
    let url = URL(string: "https://\(host)/account/profile")!
    let cookies = [
      makeCookie(name: name, value: "root", domain: host, path: "/"),
      makeCookie(name: name, value: "account", domain: host, path: "/account"),
    ]

    for cookie in cookies {
      await set(cookie, in: store)
    }

    let stored = await load(for: url, from: store).filter { $0.name == name }
    XCTAssertEqual(Set(stored.map(\.value)), Set(["root", "account"]))
    XCTAssertEqual(Set(stored.map(\.path)), Set(["/", "/account"]))

    for cookie in stored {
      await delete(cookie, from: store)
    }

    let remaining = await load(for: url, from: store).filter { $0.name == name }
    XCTAssertTrue(remaining.isEmpty)
    await clearAll(from: store)
  }

  private func makeCookie(
    name: String,
    value: String,
    domain: String,
    path: String
  ) -> HTTPCookie {
    HTTPCookie(properties: [
      .name: name,
      .value: value,
      .domain: domain,
      .path: path,
      .secure: true,
    ])!
  }

  private func set(_ cookie: HTTPCookie, in store: CookieStoreKind) async {
    await withCheckedContinuation { continuation in
      CookieStoreAccess.set(cookie, in: store) {
        continuation.resume()
      }
    }
  }

  private func load(for url: URL, from store: CookieStoreKind) async -> [HTTPCookie] {
    await withCheckedContinuation { continuation in
      CookieStoreAccess.load(
        for: url,
        from: store,
        domainMatches: { originDomain, cookieDomain in
          originDomain.caseInsensitiveCompare(cookieDomain) == .orderedSame
        }
      ) { cookies in
        continuation.resume(returning: cookies)
      }
    }
  }

  private func delete(_ cookie: HTTPCookie, from store: CookieStoreKind) async {
    await withCheckedContinuation { continuation in
      CookieStoreAccess.delete(cookie, from: store) {
        continuation.resume()
      }
    }
  }

  private func clearAll(from store: CookieStoreKind) async {
    await withCheckedContinuation { continuation in
      CookieStoreAccess.clearAll(from: store) {
        continuation.resume()
      }
    }
  }
}
