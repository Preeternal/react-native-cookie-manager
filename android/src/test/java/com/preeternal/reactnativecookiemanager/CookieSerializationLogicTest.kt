package com.preeternal.reactnativecookiemanager

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class CookieSerializationLogicTest {
  @Test
  fun serializesExistingAttributesAndFutureExpiry() {
    val result = serializeCookieForSet(
      cookie(expiresAtMillis = 1_970_000_000_000L, secure = true, httpOnly = true)
    )

    assertEquals(
      "session=value; Expires=Fri, 04 Jun 2032 22:13:20 GMT; " +
        "Domain=example.com; Path=/; Secure; HttpOnly",
      result
    )
  }

  @Test
  fun keepsPastExpiryAsADeletionInsteadOfCreatingASessionCookie() {
    val result = serializeCookieForSet(cookie(expiresAtMillis = 1_000L))

    assertEquals(
      "session=value; Expires=Thu, 01 Jan 1970 00:00:01 GMT; Domain=example.com; Path=/",
      result
    )
  }

  @Test
  fun maxAgeUsesRelativeSecondsAndTakesPrecedenceOverExpires() {
    val result = serializeCookieForSet(
      cookie(expiresAtMillis = 1_970_000_000_000L, maxAgeSeconds = 60)
    )

    assertEquals(
      "session=value; Max-Age=60; Domain=example.com; Path=/",
      result
    )
  }

  @Test
  fun serializesImmediateAndPastMaxAgeDeletion() {
    assertEquals(
      "session=value; Max-Age=0; Domain=example.com; Path=/",
      serializeCookieForSet(cookie(maxAgeSeconds = 0))
    )
    assertEquals(
      "session=value; Max-Age=-1; Domain=example.com; Path=/",
      serializeCookieForSet(cookie(maxAgeSeconds = -1))
    )
  }

  @Test
  fun serializesModernSameSiteValues() {
    assertEquals(
      "session=value; Domain=example.com; Path=/; SameSite=Lax",
      serializeCookieForSet(cookie(sameSite = CookieSameSite.LAX))
    )
    assertEquals(
      "session=value; Domain=example.com; Path=/; Secure; SameSite=None",
      serializeCookieForSet(cookie(secure = true, sameSite = CookieSameSite.NONE))
    )
  }

  @Test
  fun rejectsInsecureSameSiteNone() {
    assertThrows(IllegalArgumentException::class.java) {
      serializeCookieForSet(cookie(sameSite = CookieSameSite.NONE))
    }
  }

  @Test
  fun parsesSameSiteCaseInsensitivelyAndRejectsUnknownValues() {
    assertEquals(CookieSameSite.LAX, parseCookieSameSite("LAX"))
    assertEquals(CookieSameSite.STRICT, parseCookieSameSite("Strict"))
    assertEquals(CookieSameSite.NONE, parseCookieSameSite("none"))
    assertThrows(IllegalArgumentException::class.java) {
      parseCookieSameSite("cross-site")
    }
  }

  @Test
  fun maxAgeRequiresAFiniteSafeInteger() {
    assertEquals(60L, parseMaxAgeSeconds(60.0))
    assertEquals(-1L, parseMaxAgeSeconds(-1.0))
    for (value in listOf(1.5, Double.NaN, Double.POSITIVE_INFINITY, 9_007_199_254_740_992.0)) {
      assertThrows(IllegalArgumentException::class.java) {
        parseMaxAgeSeconds(value)
      }
    }
  }

  @Test
  fun parsesIsoExpiryOffsetsAndKeepsInvalidInputAsSessionOnly() {
    val expected = 1_970_389_094_000L

    assertEquals(
      expected,
      parseCookieExpires("2032-06-09T10:18:14.000Z")
    )
    assertEquals(
      expected,
      parseCookieExpires("2032-06-09T12:18:14.000+02:00")
    )
    assertNull(parseCookieExpires("not-a-date"))
  }

  @Test
  fun preservesLegacyAttributeSegmentsInsideValue() {
    val result = serializeCookieForSet(
      cookie(value = "value; Priority=High")
    )

    assertEquals(
      "session=value; Priority=High; Domain=example.com; Path=/",
      result
    )
  }

  private fun cookie(
    value: String = "value",
    expiresAtMillis: Long? = null,
    maxAgeSeconds: Long? = null,
    secure: Boolean = false,
    httpOnly: Boolean = false,
    sameSite: CookieSameSite? = null
  ) = CookieSetData(
    name = "session",
    value = value,
    domain = "example.com",
    path = "/",
    expiresAtMillis = expiresAtMillis,
    maxAgeSeconds = maxAgeSeconds,
    secure = secure,
    httpOnly = httpOnly,
    sameSite = sameSite
  )
}
