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

  func testIsMatchingDomainAllowsExactDomainWithLeadingDot() {
    XCTAssertTrue(
      CookieDomainLogic.isMatchingDomain(
        originDomain: "example.com",
        cookieDomain: ".example.com"
      )
    )
  }

  func testIsMatchingDomainIsCaseInsensitiveForExactDomain() {
    XCTAssertTrue(
      CookieDomainLogic.isMatchingDomain(
        originDomain: "Example.com",
        cookieDomain: "example.COM"
      )
    )
  }

  func testIsMatchingDomainIsCaseInsensitiveForParentDomain() {
    XCTAssertTrue(
      CookieDomainLogic.isMatchingDomain(
        originDomain: "App.Example.COM",
        cookieDomain: ".EXAMPLE.com"
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

  func testIsMatchingDomainRejectsSubstringDomainMatch() {
    XCTAssertFalse(
      CookieDomainLogic.isMatchingDomain(
        originDomain: "NotExample.com",
        cookieDomain: ".example.COM"
      )
    )
  }
}
