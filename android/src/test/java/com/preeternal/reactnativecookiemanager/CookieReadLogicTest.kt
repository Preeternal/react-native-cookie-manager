package com.preeternal.reactnativecookiemanager

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class CookieReadLogicTest {
  @Test
  fun returnsRawRequestCookieHeaderForUrl() {
    var requestedUrl: String? = null

    val result = readCookieHeader("https://example.com/account") { url ->
      requestedUrl = url
      "session=root; session=account; theme=dark"
    }

    assertEquals("https://example.com/account", requestedUrl)
    assertEquals("session=root; session=account; theme=dark", result)
  }

  @Test
  fun returnsEmptyHeaderWhenStoreHasNoMatchingCookies() {
    assertEquals("", readCookieHeader("https://example.com") { null })
  }

  @Test
  fun usesDetailedReaderWhenSupported() {
    var legacyReaderCalled = false

    val result = readCookieHeaders(
      supportsDetailedRead = true,
      detailedReader = { listOf("session=abc; domain=example.com; path=/") },
      legacyReader = {
        legacyReaderCalled = true
        "legacy=value"
      }
    )

    assertEquals(
      CookieReadResult.Detailed(listOf("session=abc; domain=example.com; path=/")),
      result
    )
    assertFalse(legacyReaderCalled)
  }

  @Test
  fun usesLegacyReaderWhenDetailedReadIsUnsupported() {
    var detailedReaderCalled = false

    val result = readCookieHeaders(
      supportsDetailedRead = false,
      detailedReader = {
        detailedReaderCalled = true
        emptyList()
      },
      legacyReader = { "session=abc; theme=dark" }
    )

    assertEquals(CookieReadResult.Legacy("session=abc; theme=dark"), result)
    assertFalse(detailedReaderCalled)
  }

  @Test
  fun fallsBackWhenWebViewRejectsDetailedRead() {
    val result = readCookieHeaders(
      supportsDetailedRead = true,
      detailedReader = { throw UnsupportedOperationException("Not supported") },
      legacyReader = { "session=abc" }
    )

    assertEquals(CookieReadResult.Legacy("session=abc"), result)
  }

  @Test
  fun doesNotFallbackWhenDetailedReadReturnsNoCookies() {
    var legacyReaderCalled = false

    val result = readCookieHeaders(
      supportsDetailedRead = true,
      detailedReader = { emptyList() },
      legacyReader = {
        legacyReaderCalled = true
        "legacy=value"
      }
    )

    assertEquals(CookieReadResult.Detailed(emptyList()), result)
    assertFalse(legacyReaderCalled)
  }

  @Test
  fun parsesDetailedCookieAttributes() {
    val parsedAt = 1_700_000_000_000L
    val result = CookieReadResult.Detailed(
      listOf(
        "session=abc; domain=.example.com; path=/account; max-age=3600; " +
          "secure; httponly; partitioned; samesite=lax"
      )
    )

    val cookies = parseCookieReadResult(result, parsedAt)

    assertEquals(1, cookies.size)
    assertEquals("session", cookies[0].name)
    assertEquals("abc", cookies[0].value)
    assertEquals(".example.com", cookies[0].domain)
    assertEquals("/account", cookies[0].path)
    assertEquals(parsedAt + 3_600_000L, cookies[0].expiresAt)
    assertTrue(cookies[0].secure)
    assertTrue(cookies[0].httpOnly)
  }

  @Test
  fun convertsExpiresAttributeToAbsoluteTime() {
    val parsedAt = System.currentTimeMillis()
    val expectedExpiresAt = ((parsedAt + 3_600_000L) / 1000L) * 1000L
    val formatter = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US).apply {
      timeZone = TimeZone.getTimeZone("GMT")
    }
    val expires = formatter.format(Date(expectedExpiresAt))

    val cookie = parseCookieReadResult(
      CookieReadResult.Detailed(
        listOf("session=abc; domain=example.com; path=/; expires=$expires")
      ),
      parsedAt
    ).single()

    assertEquals(expectedExpiresAt, cookie.expiresAt)
  }

  @Test
  fun maxAgeTakesPrecedenceOverExpires() {
    val parsedAt = 1_700_000_000_000L
    val cookie = parseCookieReadResult(
      CookieReadResult.Detailed(
        listOf(
          "session=abc; domain=example.com; path=/; max-age=60; " +
            "expires=Wed, 09 Jun 2032 10:18:14 GMT"
        )
      ),
      parsedAt
    ).single()

    assertEquals(parsedAt + 60_000L, cookie.expiresAt)
  }

  @Test
  fun legacyHeaderKeepsPreviousNameValueOnlyBehavior() {
    val cookies = parseCookieReadResult(
      CookieReadResult.Legacy("session=abc; theme=dark")
    )

    assertEquals(listOf("session", "theme"), cookies.map { it.name })
    assertEquals(listOf("abc", "dark"), cookies.map { it.value })
    for (cookie in cookies) {
      assertNull(cookie.domain)
      assertNull(cookie.path)
      assertNull(cookie.expiresAt)
      assertFalse(cookie.secure)
      assertFalse(cookie.httpOnly)
    }
  }

  @Test
  fun preservesDuplicateCookieNamesForArraySerialization() {
    val detailedCookies = parseCookieReadResult(
      CookieReadResult.Detailed(
        listOf(
          "session=root; domain=example.com; path=/",
          "session=account; domain=example.com; path=/account"
        )
      )
    )
    val legacyCookies = parseCookieReadResult(
      CookieReadResult.Legacy("session=root; session=account")
    )

    assertEquals(listOf("root", "account"), detailedCookies.map { it.value })
    assertEquals(listOf("/", "/account"), detailedCookies.map { it.path })
    assertEquals(listOf("root", "account"), legacyCookies.map { it.value })
  }
}
