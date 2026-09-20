package com.preeternal.reactnativecookiemanager

internal enum class CookieManagerErrorCode(val value: String) {
  INVALID_URL("invalid_url"),
  INVALID_COOKIE("invalid_cookie"),
  DOMAIN_MISMATCH("domain_mismatch"),
  NOT_SUPPORTED("not_supported"),
  STORAGE_ERROR("storage_error"),
  NETWORK_ERROR("network_error")
}

internal class CookieManagerException(
  val code: CookieManagerErrorCode,
  message: String,
  cause: Throwable? = null
) : Exception(message, cause)

internal fun cookieManagerErrorCode(
  error: Throwable,
  fallback: CookieManagerErrorCode
): String = (error as? CookieManagerException)?.code?.value ?: fallback.value
