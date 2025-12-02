package com.preeternal.reactnativecookiemanager

import android.os.Build
import android.util.Log
import android.webkit.CookieManager
import android.webkit.ValueCallback
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import java.lang.Exception
import java.net.HttpCookie
import java.net.URL
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@ReactModule(name = CookieManagerModule.NAME)
class CookieManagerModule(reactContext: ReactApplicationContext) :
  NativeCookieManagerSpec(reactContext) {

  override fun getName(): String = NAME

  override fun setCookie(
    url: String,
    cookie: ReadableMap,
    useWebKit: Boolean?,
    promise: Promise
  ) {
    val cookieString = try {
      toRFC6265string(makeHTTPCookieObject(url, cookie))
    } catch (e: Exception) {
      promise.reject("cookie_set_error", e)
      return
    }

    if (cookieString == null) {
      promise.reject("invalid_cookie_values", INVALID_COOKIE_VALUES)
      return
    }

    addCookies(url, cookieString, promise)
  }

  override fun setFromResponse(url: String, cookie: String, promise: Promise) {
    if (cookie.isEmpty()) {
      promise.reject("invalid_cookie_values", INVALID_COOKIE_VALUES)
      return
    }

    addCookies(url, cookie, promise)
  }

  override fun getCookies(url: String, useWebKit: Boolean?, promise: Promise) {
    if (url.isEmpty()) {
      promise.reject("invalid_url", INVALID_URL_MISSING_HTTP)
      return
    }

    try {
      val cookiesString = getCookieManager().getCookie(url)
      promise.resolve(createCookieList(cookiesString))
    } catch (e: Exception) {
      promise.reject("get_cookie_error", e)
    }
  }

  override fun getFromResponse(url: String, promise: Promise) {
    promise.resolve(url)
  }

  override fun getAll(useWebKit: Boolean?, promise: Promise) {
    promise.reject("not_supported", GET_ALL_NOT_SUPPORTED)
  }

  override fun clearByName(url: String, name: String, useWebKit: Boolean?, promise: Promise) {
    promise.reject("not_supported", CLEAR_BY_NAME_NOT_SUPPORTED)
  }

  override fun clearAll(useWebKit: Boolean?, promise: Promise) {
    try {
      val cookieManager = getCookieManager()
      cookieManager.removeAllCookies { promise.resolve(it) }
      cookieManager.flush()
    } catch (e: Exception) {
      promise.reject("clear_all_error", e)
    }
  }

  override fun flush(promise: Promise) {
    try {
      getCookieManager().flush()
      promise.resolve(true)
    } catch (e: Exception) {
      promise.reject("flush_error", e)
    }
  }

  override fun removeSessionCookies(promise: Promise) {
    try {
      getCookieManager().removeSessionCookies { promise.resolve(it) }
    } catch (e: Exception) {
      promise.reject("remove_session_error", e)
    }
  }

  private fun addCookies(url: String, cookieString: String, promise: Promise) {
    try {
      val cookieManager = getCookieManager()
      cookieManager.setCookie(url, cookieString) { promise.resolve(it) }
      cookieManager.flush()
    } catch (e: Exception) {
      promise.reject("add_cookie_error", e)
    }
  }

  private fun createCookieList(allCookies: String?): WritableMap {
    val allCookiesMap = Arguments.createMap()

    if (!allCookies.isNullOrEmpty()) {
      val cookieHeaders = allCookies.split(";")
      for (singleCookie in cookieHeaders) {
        val cookies = HttpCookie.parse(singleCookie)
        for (cookie in cookies) {
          if (cookie != null) {
            val name = cookie.name
            val value = cookie.value
            if (!isEmpty(name) && !isEmpty(value)) {
              val cookieMap = createCookieData(cookie)
              allCookiesMap.putMap(name, cookieMap)
            }
          }
        }
      }
    }

    return allCookiesMap
  }

  @Throws(Exception::class)
  private fun makeHTTPCookieObject(url: String, cookie: ReadableMap): HttpCookie {
    val parsedUrl = try {
      URL(url)
    } catch (e: Exception) {
      throw Exception(INVALID_URL_MISSING_HTTP)
    }

    val topLevelDomain = parsedUrl.host
    if (isEmpty(topLevelDomain)) {
      throw Exception(INVALID_URL_MISSING_HTTP)
    }

    val cookieBuilder = HttpCookie(cookie.getString("name"), cookie.getString("value"))
    if (cookie.hasKey("domain") && !isEmpty(cookie.getString("domain"))) {
      var domain = cookie.getString("domain")
      if (domain != null && domain.startsWith(".")) {
        domain = domain.substring(1)
      }

      if (domain != null && !topLevelDomain.contains(domain) && topLevelDomain != domain) {
        throw Exception(String.format(INVALID_DOMAINS, topLevelDomain, domain))
      }

      if (domain != null) {
        cookieBuilder.domain = domain
      }
    } else {
      cookieBuilder.domain = topLevelDomain
    }

    if (cookie.hasKey("path") && !isEmpty(cookie.getString("path"))) {
      cookieBuilder.path = cookie.getString("path")
    }

    if (cookie.hasKey("expires") && !isEmpty(cookie.getString("expires"))) {
      val date = parseDate(cookie.getString("expires"))
      if (date != null) {
        cookieBuilder.maxAge = date.time
      }
    }

    if (cookie.hasKey("secure") && cookie.getBoolean("secure")) {
      cookieBuilder.secure = true
    }

    if (HTTP_ONLY_SUPPORTED && cookie.hasKey("httpOnly") && cookie.getBoolean("httpOnly")) {
      cookieBuilder.isHttpOnly = true
    }

    return cookieBuilder
  }

  private fun createCookieData(cookie: HttpCookie): WritableMap {
    val cookieMap = Arguments.createMap()
    cookieMap.putString("name", cookie.name)
    cookieMap.putString("value", cookie.value)
    cookieMap.putString("domain", cookie.domain)
    cookieMap.putString("path", cookie.path)
    cookieMap.putBoolean("secure", cookie.secure)
    if (HTTP_ONLY_SUPPORTED) {
      cookieMap.putBoolean("httpOnly", cookie.isHttpOnly)
    }

    val expires = cookie.maxAge
    if (expires > 0) {
      val expiry = formatDate(Date(expires))
      if (!isEmpty(expiry)) {
        cookieMap.putString("expires", expiry)
      }
    }

    return cookieMap
  }

  private fun getCookieManager(): CookieManager {
    val cookieManager = CookieManager.getInstance()
    cookieManager.setAcceptCookie(true)
    return cookieManager
  }

  private fun isEmpty(value: String?): Boolean {
    return value == null || value.isEmpty()
  }

  private fun dateFormatter(): DateFormat {
    val df = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ", Locale.US)
    df.timeZone = TimeZone.getTimeZone("GMT")
    return df
  }

  private fun rfc1123DateFormatter(): DateFormat {
    val df = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US)
    df.timeZone = TimeZone.getTimeZone("GMT")
    return df
  }

  private fun parseDate(dateString: String?, rfc1123: Boolean = false): Date? {
    if (dateString.isNullOrEmpty()) return null
    return try {
      (if (rfc1123) rfc1123DateFormatter() else dateFormatter()).parse(dateString)
    } catch (e: Exception) {
      Log.i(NAME, e.message ?: "Unable to parse date")
      null
    }
  }

  private fun formatDate(date: Date, rfc1123: Boolean = false): String? {
    return try {
      (if (rfc1123) rfc1123DateFormatter() else dateFormatter()).format(date)
    } catch (e: Exception) {
      Log.i(NAME, e.message ?: "Unable to format date")
      null
    }
  }

  private fun toRFC6265string(cookie: HttpCookie?): String? {
    if (cookie == null) return null
    val builder = StringBuilder()
    builder.append(cookie.name).append('=').append(cookie.value)

    if (!cookie.hasExpired()) {
      val expiresAt = cookie.maxAge
      if (expiresAt > 0) {
        val dateString = formatDate(Date(expiresAt), true)
        if (!isEmpty(dateString)) {
          builder.append("; expires=").append(dateString)
        }
      }
    }

    if (!isEmpty(cookie.domain)) {
      builder.append("; domain=").append(cookie.domain)
    }

    if (!isEmpty(cookie.path)) {
      builder.append("; path=").append(cookie.path)
    }

    if (cookie.secure) {
      builder.append("; secure")
    }

    if (HTTP_ONLY_SUPPORTED && cookie.isHttpOnly) {
      builder.append("; httponly")
    }

    return builder.toString()
  }

  companion object {
    private const val INVALID_URL_MISSING_HTTP =
      "Invalid URL: It may be missing a protocol (ex. http:// or https://)."
    private const val INVALID_COOKIE_VALUES = "Unable to add cookie - invalid values"
    private const val GET_ALL_NOT_SUPPORTED = "Get all cookies not supported for Android (iOS only)"
    private const val CLEAR_BY_NAME_NOT_SUPPORTED = "Cannot remove a single cookie by name on Android"
    private const val INVALID_DOMAINS =
      "Cookie URL host %s and domain %s mismatched. The cookie won't set correctly."

    private val USES_LEGACY_STORE = Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP
    private val HTTP_ONLY_SUPPORTED = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

    const val NAME = "CookieManager"
  }
}
