package com.preeternal.reactnativecookiemanager

import org.junit.Assert.assertThrows
import org.junit.Test

class CookieValidationLogicTest {
  @Test
  fun acceptsPrintableLegacyValuesWithoutEncoding() {
    for (value in listOf("a=b", "value with spaces", "quoted\"value", "žluťoučký")) {
      validateStructuredCookieStrings(input(value = value), validate = true)
    }
  }

  @Test
  fun structuralChecksCannotBeDisabled() {
    val unsafeInputs = listOf(
      input(name = "a=b"),
      input(name = "a;b"),
      input(value = "value; Secure"),
      input(domain = "example.com; Secure"),
      input(path = "/; Secure"),
      input(value = "line\nbreak"),
      input(value = "nul\u0000byte"),
      input(path = "/tab\tpath")
    )

    for (unsafeInput in unsafeInputs) {
      assertThrows(IllegalArgumentException::class.java) {
        validateStructuredCookieStrings(unsafeInput, validate = false)
      }
    }
  }

  @Test
  fun strictChecksCanUseTheTemporaryCompatibilityPath() {
    val legacyInputs = listOf(
      input(name = "legacy name"),
      input(path = "relative"),
      input(expires = "not-a-date")
    )

    for (legacyInput in legacyInputs) {
      assertThrows(IllegalArgumentException::class.java) {
        validateStructuredCookieStrings(legacyInput, validate = true)
      }
      validateStructuredCookieStrings(legacyInput, validate = false)
    }
  }

  @Test
  fun rawHeaderAllowsAttributesButRejectsHeaderInjection() {
    validateRawSetCookieHeader("session=value; Secure; HttpOnly")

    for (header in listOf("", "session=value\r\nInjected: true", "session=\u0000value")) {
      assertThrows(IllegalArgumentException::class.java) {
        validateRawSetCookieHeader(header)
      }
    }
  }

  private fun input(
    name: String = "session",
    value: String = "value",
    domain: String? = "example.com",
    path: String? = "/",
    version: String? = null,
    expires: String? = null,
    sameSite: String? = null
  ) = StructuredCookieStrings(
    name = name,
    value = value,
    domain = domain,
    path = path,
    version = version,
    expires = expires,
    sameSite = sameSite
  )
}
