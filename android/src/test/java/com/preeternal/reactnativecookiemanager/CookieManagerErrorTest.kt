package com.preeternal.reactnativecookiemanager

import org.junit.Assert.assertEquals
import org.junit.Test

class CookieManagerErrorTest {
  @Test
  fun publicCodesStaySmallAndStable() {
    assertEquals(
      setOf(
        "invalid_url",
        "invalid_cookie",
        "domain_mismatch",
        "not_supported",
        "storage_error",
        "network_error"
      ),
      CookieManagerErrorCode.entries.map { it.value }.toSet()
    )
  }

  @Test
  fun typedErrorsKeepTheirCodeAndGenericErrorsUseTheFallback() {
    val typedError = CookieManagerException(
      CookieManagerErrorCode.DOMAIN_MISMATCH,
      "Domain mismatch"
    )

    assertEquals(
      "domain_mismatch",
      cookieManagerErrorCode(typedError, CookieManagerErrorCode.INVALID_COOKIE)
    )
    assertEquals(
      "storage_error",
      cookieManagerErrorCode(Exception("Native detail"), CookieManagerErrorCode.STORAGE_ERROR)
    )
  }
}
