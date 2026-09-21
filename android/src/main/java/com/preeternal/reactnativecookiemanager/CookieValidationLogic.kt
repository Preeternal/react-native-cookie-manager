package com.preeternal.reactnativecookiemanager

internal data class StructuredCookieStrings(
  val name: String,
  val value: String,
  val domain: String?,
  val path: String?,
  val version: String?,
  val expires: String?,
  val sameSite: String?
)

internal fun validateStructuredCookieStrings(
  input: StructuredCookieStrings,
  validate: Boolean
) {
  if (input.name.isEmpty()) {
    throw IllegalArgumentException("Cookie name must not be empty")
  }

  listOfNotNull(
    "name" to input.name,
    "value" to input.value,
    input.domain?.let { "domain" to it },
    input.path?.let { "path" to it },
    input.version?.let { "version" to it },
    input.expires?.let { "expires" to it },
    input.sameSite?.let { "sameSite" to it }
  ).forEach { (field, value) ->
    if (value.any(::isAsciiControlCharacter)) {
      throw IllegalArgumentException("Cookie $field must not contain control characters")
    }
  }

  if (input.name.contains('=') || input.name.contains(';')) {
    throw IllegalArgumentException("Cookie name must not contain \"=\" or \";\"")
  }
  if (input.value.contains(';')) {
    throw IllegalArgumentException(
      "Cookie value must not contain \";\" because native stores treat it as an attribute separator"
    )
  }
  if (input.domain?.contains(';') == true) {
    throw IllegalArgumentException("Cookie domain must not contain \";\"")
  }
  if (input.path?.contains(';') == true) {
    throw IllegalArgumentException("Cookie path must not contain \";\"")
  }

  if (!validate) {
    return
  }

  if (!isPortableCookieName(input.name)) {
    throw IllegalArgumentException("Cookie name contains characters unsupported by native stores")
  }
  if (!input.path.isNullOrEmpty() && !input.path.startsWith('/')) {
    throw IllegalArgumentException("Cookie path must start with \"/\"")
  }
  if (!input.expires.isNullOrEmpty() && parseCookieExpires(input.expires) == null) {
    throw IllegalArgumentException("Cookie expires must be a valid ISO 8601 date")
  }
}

internal fun validateRawSetCookieHeader(cookie: String) {
  if (cookie.isEmpty()) {
    throw IllegalArgumentException("Cookie header must not be empty")
  }
  if (cookie.any { it == '\r' || it == '\n' || it == '\u0000' }) {
    throw IllegalArgumentException("Cookie header must not contain CR, LF, or NUL")
  }
}

private fun isAsciiControlCharacter(character: Char): Boolean =
  character.code <= 0x1F || character.code == 0x7F

private fun isPortableCookieName(name: String): Boolean =
  !name.startsWith('$') && name.all { character ->
    character in 'a'..'z' ||
      character in 'A'..'Z' ||
      character in '0'..'9' ||
      character in "!#$%&'*+-.^_`|~"
  }
