import XCTest
@testable import CookieManagerError

final class CookieManagerErrorTests: XCTestCase {
  func testPublicCodesStaySmallAndStable() {
    XCTAssertEqual(
      Set(CookieManagerErrorCode.allCases.map(\.rawValue)),
      Set([
        "invalid_url",
        "invalid_cookie",
        "domain_mismatch",
        "not_supported",
        "storage_error",
        "network_error",
      ])
    )
  }

  func testInputErrorPreservesCodeMessageAndUnderlyingError() {
    let underlyingError = NSError(
      domain: "CookieManagerTests",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Native detail"]
    )
    let error = CookieManagerInputError(
      code: .invalidCookie,
      message: "Invalid cookie",
      underlyingError: underlyingError
    )

    XCTAssertEqual(error.code, .invalidCookie)
    XCTAssertEqual(error.localizedDescription, "Invalid cookie")
    XCTAssertNotNil(error.underlyingError)
  }
}
