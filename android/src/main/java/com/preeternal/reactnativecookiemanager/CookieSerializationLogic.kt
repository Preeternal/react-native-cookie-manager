package com.preeternal.reactnativecookiemanager

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal enum class CookieSameSite(val attributeValue: String) {
  LAX("Lax"),
  STRICT("Strict"),
  NONE("None")
}

internal data class CookieSetData(
  val name: String,
  val value: String,
  val domain: String?,
  val path: String?,
  val expiresAtMillis: Long?,
  val maxAgeSeconds: Long?,
  val secure: Boolean,
  val httpOnly: Boolean,
  val sameSite: CookieSameSite?
)

internal fun parseCookieSameSite(value: String): CookieSameSite =
  when (value.lowercase(Locale.US)) {
    "lax" -> CookieSameSite.LAX
    "strict" -> CookieSameSite.STRICT
    "none" -> CookieSameSite.NONE
    else -> throw IllegalArgumentException("sameSite must be \"lax\", \"strict\", or \"none\"")
  }

internal fun parseMaxAgeSeconds(value: Double): Long {
  if (!value.isFinite() || value % 1.0 != 0.0 || kotlin.math.abs(value) > MAX_SAFE_INTEGER) {
    throw IllegalArgumentException("maxAge must be a finite safe integer number of seconds")
  }
  return value.toLong()
}

internal fun parseCookieExpires(value: String?): Long? {
  if (value.isNullOrEmpty()) return null
  return try {
    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ", Locale.US).apply {
      timeZone = TimeZone.getTimeZone("GMT")
    }.parse(value)?.time
  } catch (_: Exception) {
    null
  }
}

internal fun serializeCookieForSet(cookie: CookieSetData): String {
  if (cookie.sameSite == CookieSameSite.NONE && !cookie.secure) {
    throw IllegalArgumentException("SameSite \"none\" requires secure: true")
  }

  return buildString {
    append(cookie.name).append('=').append(cookie.value)

    if (cookie.maxAgeSeconds != null) {
      append("; Max-Age=").append(cookie.maxAgeSeconds)
    } else if (cookie.expiresAtMillis != null) {
      append("; Expires=").append(formatRfc1123(Date(cookie.expiresAtMillis)))
    }

    if (!cookie.domain.isNullOrEmpty()) {
      append("; Domain=").append(cookie.domain)
    }
    if (!cookie.path.isNullOrEmpty()) {
      append("; Path=").append(cookie.path)
    }
    if (cookie.secure) {
      append("; Secure")
    }
    if (cookie.httpOnly) {
      append("; HttpOnly")
    }
    cookie.sameSite?.let { append("; SameSite=").append(it.attributeValue) }
  }
}

private fun formatRfc1123(date: Date): String =
  SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US).apply {
    timeZone = TimeZone.getTimeZone("GMT")
  }.format(date)

private const val MAX_SAFE_INTEGER = 9_007_199_254_740_991.0
