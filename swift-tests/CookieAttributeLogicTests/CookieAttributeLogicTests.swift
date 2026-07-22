import Foundation
import XCTest
@testable import CookieAttributeLogic

final class CookieAttributeLogicTests: XCTestCase {
  func testMaxAgeUsesRelativeSecondsAndTakesPrecedenceOverExpires() throws {
    var properties = baseProperties()
    let beforeCreation = Date()

    try CookieAttributeLogic.apply(
      props: [
        "maxAge": 60,
        "expires": "2032-06-09T10:18:14.000Z",
      ],
      secure: false,
      to: &properties,
      parseDate: { _ in Date(timeIntervalSince1970: 1_970_000_000) }
    )

    XCTAssertEqual(properties[.maximumAge] as? String, "60")
    XCTAssertNil(properties[.expires])
    let cookie = try XCTUnwrap(HTTPCookie(properties: properties))
    let expiry = try XCTUnwrap(cookie.expiresDate)
    XCTAssertGreaterThanOrEqual(expiry, beforeCreation.addingTimeInterval(59))
    XCTAssertLessThanOrEqual(expiry, Date().addingTimeInterval(61))
  }

  func testMaxAgeAcceptsImmediateAndPastExpiry() throws {
    for maxAge in [0, -1] {
      var properties = baseProperties()

      try CookieAttributeLogic.apply(
        props: ["maxAge": maxAge],
        secure: false,
        to: &properties,
        parseDate: { _ in nil }
      )

      XCTAssertEqual(properties[.maximumAge] as? String, String(maxAge))
    }
  }

  func testInvalidExpiresRetainsPreviousSessionCookieBehavior() throws {
    var properties = baseProperties()

    try CookieAttributeLogic.apply(
      props: ["expires": "not-a-date"],
      secure: false,
      to: &properties,
      parseDate: { _ in nil }
    )

    XCTAssertNil(properties[.expires])
    XCTAssertNil(properties[.maximumAge])
  }

  func testRejectsNonIntegerAndNonFiniteMaxAge() {
    for maxAge in [1.5, Double.nan, Double.infinity] {
      var properties = baseProperties()

      XCTAssertThrowsError(
        try CookieAttributeLogic.apply(
          props: ["maxAge": maxAge],
          secure: false,
          to: &properties,
          parseDate: { _ in nil }
        )
      )
    }
  }

  func testSameSiteIsNormalizedAndReadable() throws {
    for (input, expected) in [("Lax", "lax"), ("STRICT", "strict")] {
      var properties = baseProperties()

      try CookieAttributeLogic.apply(
        props: ["sameSite": input],
        secure: false,
        to: &properties,
        parseDate: { _ in nil }
      )

      let cookie = try XCTUnwrap(HTTPCookie(properties: properties))
      XCTAssertEqual(CookieAttributeLogic.sameSiteValue(from: cookie), expected)
    }
  }

  func testSecureSameSiteNoneUsesFoundationsUnrestrictedPolicy() throws {
    var properties = baseProperties()

    try CookieAttributeLogic.apply(
      props: ["sameSite": "none"],
      secure: true,
      to: &properties,
      parseDate: { _ in nil }
    )

    XCTAssertNil(properties[.sameSitePolicy])
    let cookie = try XCTUnwrap(HTTPCookie(properties: properties))
    XCTAssertNil(CookieAttributeLogic.sameSiteValue(from: cookie))
  }

  func testRejectsInsecureSameSiteNoneAndUnknownValues() {
    for sameSite in ["none", "invalid"] {
      var properties = baseProperties()

      XCTAssertThrowsError(
        try CookieAttributeLogic.apply(
          props: ["sameSite": sameSite],
          secure: false,
          to: &properties,
          parseDate: { _ in nil }
        )
      )
    }
  }

  private func baseProperties() -> [HTTPCookiePropertyKey: Any] {
    [
      .name: "session",
      .value: "value",
      .domain: "example.com",
      .path: "/",
    ]
  }
}
