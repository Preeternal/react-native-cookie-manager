import Foundation
import XCTest
@testable import CookieValidationLogic

final class CookieValidationLogicTests: XCTestCase {
  func testAcceptsPrintableValuesWithoutEncoding() throws {
    for value in ["a=b", "value with spaces", "quoted\"value", "žluťoučký"] {
      try validate(value: value)
    }
  }

  func testStructuralChecksCannotBeDisabled() {
    let cases: [(String, String, String?, String?)] = [
      ("a=b", "value", "example.com", "/"),
      ("a;b", "value", "example.com", "/"),
      ("session", "value; Secure", "example.com", "/"),
      ("session", "value", "example.com; Secure", "/"),
      ("session", "value", "example.com", "/; Secure"),
      ("session", "line\nbreak", "example.com", "/"),
      ("session", "nul\0byte", "example.com", "/"),
      ("session", "value", "example.com", "/tab\tpath"),
    ]

    for (name, value, domain, path) in cases {
      XCTAssertThrowsError(
        try validate(
          name: name,
          value: value,
          domain: domain,
          path: path,
          strict: false
        )
      )
    }
  }

  func testStrictChecksCanUseTheTemporaryCompatibilityPath() throws {
    XCTAssertThrowsError(try validate(name: "legacy name"))
    try validate(name: "legacy name", strict: false)

    XCTAssertThrowsError(try validate(path: "relative"))
    try validate(path: "relative", strict: false)

    XCTAssertThrowsError(try validate(expires: "not-a-date"))
    try validate(expires: "not-a-date", strict: false)
  }

  func testRawHeaderAllowsAttributesButRejectsHeaderInjection() throws {
    try CookieValidationLogic.validateRawSetCookieHeader(
      "session=value; Secure; HttpOnly"
    )

    for header in ["", "session=value\r\nInjected: true", "session=\0value"] {
      XCTAssertThrowsError(
        try CookieValidationLogic.validateRawSetCookieHeader(header),
        "Expected rejection for \(header.debugDescription)"
      )
    }
  }

  private func validate(
    name: String = "session",
    value: String = "value",
    domain: String? = "example.com",
    path: String? = "/",
    version: String? = nil,
    expires: String? = nil,
    sameSite: String? = nil,
    strict: Bool = true
  ) throws {
    try CookieValidationLogic.validateStructuredStrings(
      name: name,
      value: value,
      domain: domain,
      path: path,
      version: version,
      expires: expires,
      sameSite: sameSite,
      validate: strict,
      parseDate: { value in
        ISO8601DateFormatter().date(from: value)
      }
    )
  }
}
