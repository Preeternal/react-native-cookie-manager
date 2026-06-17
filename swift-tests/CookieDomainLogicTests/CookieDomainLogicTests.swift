import XCTest
@testable import CookieDomainLogic

final class CookieDomainLogicTests: XCTestCase {
  func testNormalizedInputDomainPreservesLeadingDot() {
    XCTAssertEqual(
      CookieDomainLogic.normalizedInputDomain("  .trustedhealth.com "),
      ".trustedhealth.com"
    )
  }

  func testNormalizedInputDomainReturnsNilForEmptyValue() {
    XCTAssertNil(CookieDomainLogic.normalizedInputDomain("   "))
    XCTAssertNil(CookieDomainLogic.normalizedInputDomain(nil))
  }

  func testValidationDomainRemovesLeadingDotOnlyForValidation() {
    XCTAssertEqual(
      CookieDomainLogic.validationDomain(from: ".trustedhealth.com"),
      "trustedhealth.com"
    )
    XCTAssertEqual(
      CookieDomainLogic.validationDomain(from: "trustedhealth.com"),
      "trustedhealth.com"
    )
  }

  func testIsCookieDomainValidAllowsParentDomainWithLeadingDot() {
    XCTAssertTrue(
      CookieDomainLogic.isCookieDomainValid(
        host: "app.trustedhealth.com",
        cookieDomain: ".trustedhealth.com"
      )
    )
  }

  func testIsCookieDomainValidRejectsMismatchedDomain() {
    XCTAssertFalse(
      CookieDomainLogic.isCookieDomainValid(
        host: "app.trustedhealth.com",
        cookieDomain: ".evil.com"
      )
    )
  }

  func testIsCookieDomainValidRejectsSubstringDomainMatch() {
    XCTAssertFalse(
      CookieDomainLogic.isCookieDomainValid(
        host: "notexample.com",
        cookieDomain: "example.com"
      )
    )
    XCTAssertFalse(
      CookieDomainLogic.isCookieDomainValid(
        host: "badexample.com",
        cookieDomain: "example.com"
      )
    )
  }

  func testIsCookieDomainValidIsCaseInsensitive() {
    XCTAssertTrue(
      CookieDomainLogic.isCookieDomainValid(
        host: "APP.EXAMPLE.COM",
        cookieDomain: "example.com"
      )
    )
  }

  func testIsMatchingDomainAllowsParentDomainWithoutLeadingDot() {
    XCTAssertTrue(
      CookieDomainLogic.isMatchingDomain(
        originDomain: "app.trustedhealth.com",
        cookieDomain: "trustedhealth.com"
      )
    )
  }

  func testIsMatchingDomainAllowsParentDomainWithLeadingDot() {
    XCTAssertTrue(
      CookieDomainLogic.isMatchingDomain(
        originDomain: "app.trustedhealth.com",
        cookieDomain: ".trustedhealth.com"
      )
    )
  }

  func testIsMatchingDomainRejectsUnrelatedDomain() {
    XCTAssertFalse(
      CookieDomainLogic.isMatchingDomain(
        originDomain: "app.trustedhealth.com",
        cookieDomain: "example.org"
      )
    )
  }
}
