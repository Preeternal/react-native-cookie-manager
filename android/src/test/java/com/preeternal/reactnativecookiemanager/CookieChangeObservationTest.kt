package com.preeternal.reactnativecookiemanager

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class CookieChangeObservationTest {
  @Test
  fun `Android rejects cookie change observation instead of emulating mutations`() {
    val error = assertThrows(UnsupportedOperationException::class.java) {
      rejectCookieChangeObservation()
    }

    assertEquals(COOKIE_CHANGE_OBSERVATION_NOT_SUPPORTED, error.message)
  }
}
