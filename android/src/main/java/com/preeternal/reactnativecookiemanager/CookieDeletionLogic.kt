package com.preeternal.reactnativecookiemanager

import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

internal sealed interface CookieDeletionPlan {
  data object Unsupported : CookieDeletionPlan

  data class Ready(val headers: List<String>) : CookieDeletionPlan
}

internal fun planCookieDeletion(
  name: String,
  supportsDetailedRead: Boolean,
  detailedReader: () -> List<String>
): CookieDeletionPlan {
  if (!supportsDetailedRead) return CookieDeletionPlan.Unsupported

  val storedHeaders = try {
    detailedReader()
  } catch (_: UnsupportedOperationException) {
    return CookieDeletionPlan.Unsupported
  }

  return CookieDeletionPlan.Ready(
    storedHeaders.mapNotNull { deletionHeader(it, name) }
  )
}

internal fun executeCookieDeletion(
  headers: List<String>,
  setter: (header: String, callback: (Boolean) -> Unit) -> Unit,
  completion: (Result<Boolean>) -> Unit
) {
  if (headers.isEmpty()) {
    completion(Result.success(false))
    return
  }

  val remaining = AtomicInteger(headers.size)
  val completed = AtomicBoolean(false)
  val failure = AtomicReference<Throwable?>(null)

  fun finishOne() {
    if (remaining.decrementAndGet() == 0 && completed.compareAndSet(false, true)) {
      val error = failure.get()
      if (error == null) {
        completion(Result.success(true))
      } else {
        completion(Result.failure(error))
      }
    }
  }

  for (header in headers) {
    try {
      setter(header) { accepted ->
        if (!accepted) {
          failure.compareAndSet(
            null,
            CookieDeletionException("Android System WebView provider rejected a cookie deletion")
          )
        }
        finishOne()
      }
    } catch (error: Exception) {
      failure.compareAndSet(null, error)
      finishOne()
    }
  }
}

private fun deletionHeader(storedHeader: String, requestedName: String): String? {
  val segments = storedHeader.split(';')
  val nameValue = segments.firstOrNull()?.trim().orEmpty()
  val separator = nameValue.indexOf('=')
  if (separator <= 0) return null

  val storedName = nameValue.substring(0, separator).trim()
  if (storedName != requestedName) return null

  val attributes = buildMap<String, String?> {
    for (segment in segments.drop(1)) {
      val attribute = segment.trim()
      if (attribute.isEmpty()) continue

      val attributeSeparator = attribute.indexOf('=')
      val key = if (attributeSeparator < 0) {
        attribute
      } else {
        attribute.substring(0, attributeSeparator)
      }.trim().lowercase(Locale.US)
      val value = if (attributeSeparator < 0) {
        null
      } else {
        attribute.substring(attributeSeparator + 1).trim()
      }
      put(key, value)
    }
  }

  val domain = attributes["domain"]
  val path = attributes["path"]
  require(!domain.isNullOrEmpty() && !path.isNullOrEmpty()) {
    "GET_COOKIE_INFO returned a matching cookie without domain or path"
  }

  return buildString {
    append(storedName)
    append("=; Path=")
    append(path)
    if (domain.startsWith('.')) {
      append("; Domain=")
      append(domain)
    }
    append("; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT")
    if (attributes.containsKey("secure") || attributes.containsKey("partitioned")) {
      append("; Secure")
    }
    if (attributes.containsKey("httponly")) {
      append("; HttpOnly")
    }
    if (attributes.containsKey("partitioned")) {
      append("; Partitioned")
    }
  }
}

private class CookieDeletionException(message: String) : Exception(message)
