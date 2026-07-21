package com.preeternal.reactnativecookiemanager

import java.net.HttpCookie
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

internal sealed interface CookieReadResult {
  data class Detailed(val headers: List<String>) : CookieReadResult

  data class Legacy(val header: String?) : CookieReadResult
}

internal data class ParsedCookie(
  val name: String,
  val value: String,
  val domain: String?,
  val path: String?,
  val expiresAt: Long?,
  val secure: Boolean,
  val httpOnly: Boolean,
  val sameSite: String?
)

internal fun readCookieHeaders(
  supportsDetailedRead: Boolean,
  detailedReader: () -> List<String>,
  legacyReader: () -> String?
): CookieReadResult {
  if (supportsDetailedRead) {
    try {
      return CookieReadResult.Detailed(detailedReader())
    } catch (_: UnsupportedOperationException) {
      // The installed WebView is the final authority for feature support.
    }
  }

  return CookieReadResult.Legacy(legacyReader())
}

internal fun readCookieHeader(
  url: String,
  reader: (String) -> String?
): String = reader(url).orEmpty()

internal fun parseCookieReadResult(
  result: CookieReadResult,
  parsedAtMillis: Long = System.currentTimeMillis()
): List<ParsedCookie> {
  val headers = when (result) {
    is CookieReadResult.Detailed -> result.headers
    is CookieReadResult.Legacy -> result.header?.split(';') ?: emptyList()
  }
  val hasAttributes = result is CookieReadResult.Detailed

  return headers.flatMap { header ->
    if (header.isBlank()) {
      emptyList()
    } else {
      HttpCookie.parse(header).mapNotNull { cookie ->
        if (cookie.name.isEmpty() || cookie.value.isEmpty()) {
          null
        } else {
          ParsedCookie(
            name = cookie.name,
            value = cookie.value,
            domain = cookie.domain,
            path = cookie.path,
            expiresAt = if (hasAttributes) {
              expirationTime(header, parsedAtMillis, cookie.maxAge)
            } else {
              null
            },
            secure = cookie.secure,
            httpOnly = cookie.isHttpOnly,
            sameSite = if (hasAttributes) parseSameSiteAttribute(header) else null
          )
        }
      }
    }
  }
}

internal fun parseSameSiteAttribute(header: String): String? =
  SAME_SITE_ATTRIBUTE.find(header)?.groupValues?.get(1)?.trim()?.lowercase(Locale.US)
    ?.takeIf { it == "lax" || it == "strict" || it == "none" }

private fun expirationTime(
  header: String,
  parsedAtMillis: Long,
  maxAgeSeconds: Long
): Long? {
  val maxAgeAttribute = MAX_AGE_ATTRIBUTE.find(header)?.groupValues?.get(1)?.trim()
  if (maxAgeAttribute?.toLongOrNull() == null) {
    val expiresAttribute = EXPIRES_ATTRIBUTE.find(header)?.groupValues?.get(1)?.trim()
    parseExpires(expiresAttribute)?.let { return it }
  }

  if (maxAgeSeconds < 0) return null

  return try {
    Math.addExact(parsedAtMillis, Math.multiplyExact(maxAgeSeconds, 1000L))
  } catch (_: ArithmeticException) {
    null
  }
}

private fun parseExpires(value: String?): Long? {
  if (value.isNullOrEmpty()) return null

  return try {
    SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US).apply {
      isLenient = false
      timeZone = TimeZone.getTimeZone("GMT")
    }.parse(value)?.time
  } catch (_: Exception) {
    null
  }
}

private val MAX_AGE_ATTRIBUTE =
  Regex("(?:^|;)\\s*max-age\\s*=\\s*([^;]*)", RegexOption.IGNORE_CASE)
private val EXPIRES_ATTRIBUTE =
  Regex("(?:^|;)\\s*expires\\s*=\\s*([^;]*)", RegexOption.IGNORE_CASE)
private val SAME_SITE_ATTRIBUTE =
  Regex("(?:^|;)\\s*samesite\\s*=\\s*([^;]*)", RegexOption.IGNORE_CASE)
