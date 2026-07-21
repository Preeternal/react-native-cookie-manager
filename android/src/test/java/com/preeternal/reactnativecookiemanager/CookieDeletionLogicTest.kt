package com.preeternal.reactnativecookiemanager

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CookieDeletionLogicTest {
  @Test
  fun reportsUnsupportedWithoutDetailedCookieInfo() {
    var readerCalled = false

    val plan = planCookieDeletion(
      name = "session",
      supportsDetailedRead = false,
      detailedReader = {
        readerCalled = true
        emptyList()
      }
    )

    assertEquals(CookieDeletionPlan.Unsupported, plan)
    assertFalse(readerCalled)
  }

  @Test
  fun reportsUnsupportedWhenProviderRejectsDetailedCookieInfo() {
    val plan = planCookieDeletion(
      name = "session",
      supportsDetailedRead = true,
      detailedReader = { throw UnsupportedOperationException("Not supported") }
    )

    assertEquals(CookieDeletionPlan.Unsupported, plan)
  }

  @Test
  fun createsExactHostOnlyAndDomainDeletionHeaders() {
    val plan = planCookieDeletion(
      name = "session",
      supportsDetailedRead = true,
      detailedReader = {
        listOf(
          "session=root; domain=www.example.com; path=/; secure; httponly",
          "session=account; domain=.example.com; path=/account",
          "theme=dark; domain=www.example.com; path=/"
        )
      }
    ) as CookieDeletionPlan.Ready

    assertEquals(2, plan.headers.size)
    assertTrue(plan.headers[0].startsWith("session=; Path=/; Max-Age=0;"))
    assertFalse(plan.headers[0].contains("Domain="))
    assertTrue(plan.headers[0].endsWith("; Secure; HttpOnly"))
    assertTrue(plan.headers[1].contains("Path=/account; Domain=.example.com; Max-Age=0"))
  }

  @Test
  fun preservesAttributesRequiredToDeletePartitionedCookies() {
    val plan = planCookieDeletion(
      name = "partitioned",
      supportsDetailedRead = true,
      detailedReader = {
        listOf(
          "partitioned=value; domain=www.example.com; path=/; " +
            "partitioned; samesite=none"
        )
      }
    ) as CookieDeletionPlan.Ready

    assertTrue(plan.headers.single().endsWith("; Secure; Partitioned"))
    assertFalse(plan.headers.single().contains("SameSite"))
  }

  @Test
  fun preservesAttributesRequiredToDeleteHostPrefixedCookies() {
    val plan = planCookieDeletion(
      name = "__Host-session",
      supportsDetailedRead = true,
      detailedReader = {
        listOf("__Host-session=value; domain=www.example.com; path=/; secure")
      }
    ) as CookieDeletionPlan.Ready

    val header = plan.headers.single()
    assertTrue(header.startsWith("__Host-session=; Path=/;"))
    assertFalse(header.contains("Domain="))
    assertTrue(header.endsWith("; Secure"))
  }

  @Test
  fun cookieNamesAreMatchedCaseSensitively() {
    val plan = planCookieDeletion(
      name = "session",
      supportsDetailedRead = true,
      detailedReader = {
        listOf("Session=value; domain=example.com; path=/")
      }
    ) as CookieDeletionPlan.Ready

    assertTrue(plan.headers.isEmpty())
  }

  @Test(expected = IllegalArgumentException::class)
  fun rejectsMatchingDetailedCookieWithoutIdentityAttributes() {
    planCookieDeletion(
      name = "session",
      supportsDetailedRead = true,
      detailedReader = { listOf("session=value; secure") }
    )
  }

  @Test
  fun emptyPlanCompletesFalseWithoutCallingSetter() {
    var setterCalled = false
    var result: Result<Boolean>? = null

    executeCookieDeletion(
      headers = emptyList(),
      setter = { _, _ -> setterCalled = true },
      completion = { result = it }
    )

    assertFalse(setterCalled)
    assertEquals(false, result?.getOrNull())
  }

  @Test
  fun waitsForEveryDeletionCallback() {
    val callbacks = mutableListOf<(Boolean) -> Unit>()
    var result: Result<Boolean>? = null

    executeCookieDeletion(
      headers = listOf("first", "second"),
      setter = { _, callback -> callbacks.add(callback) },
      completion = { result = it }
    )

    assertEquals(2, callbacks.size)
    assertEquals(null, result)
    callbacks[1](true)
    assertEquals(null, result)
    callbacks[0](true)
    assertEquals(true, result?.getOrNull())
  }

  @Test
  fun reportsRejectedDeletionAfterAllCallbacks() {
    val callbacks = mutableListOf<(Boolean) -> Unit>()
    var result: Result<Boolean>? = null

    executeCookieDeletion(
      headers = listOf("first", "second"),
      setter = { _, callback -> callbacks.add(callback) },
      completion = { result = it }
    )

    callbacks[0](false)
    assertEquals(null, result)
    callbacks[1](true)
    assertTrue(result?.isFailure == true)
  }

  @Test
  fun waitsForStartedCallbacksAfterSynchronousSetterFailure() {
    var firstCallback: ((Boolean) -> Unit)? = null
    var thirdCallback: ((Boolean) -> Unit)? = null
    var completionCount = 0
    var result: Result<Boolean>? = null
    var error: Throwable? = null

    executeCookieDeletion(
      headers = listOf("first", "second", "third"),
      setter = { header, callback ->
        when (header) {
          "first" -> firstCallback = callback
          "second" -> throw IllegalStateException("failed")
          "third" -> thirdCallback = callback
        }
      },
      completion = {
        completionCount += 1
        result = it
        error = it.exceptionOrNull()
      }
    )

    assertEquals(null, result)
    firstCallback?.invoke(true)
    assertEquals(null, result)
    thirdCallback?.invoke(true)
    assertEquals(1, completionCount)
    assertNotNull(error)
  }
}
