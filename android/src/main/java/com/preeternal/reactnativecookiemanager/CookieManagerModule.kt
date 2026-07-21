package com.preeternal.reactnativecookiemanager

import android.os.Build
import android.util.Log
import android.webkit.CookieManager
import android.webkit.ValueCallback
import androidx.webkit.CookieManagerCompat
import androidx.webkit.WebViewFeature
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import java.lang.Exception
import java.net.HttpCookie
import java.net.HttpURLConnection
import java.net.ProtocolException
import java.net.SocketTimeoutException
import java.net.URL
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

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
      promise.resolve(createCookieList(readCookies(url)))
    } catch (e: Exception) {
      promise.reject("get_cookie_error", e)
    }
  }

  override fun getAsArray(url: String, useWebKit: Boolean?, promise: Promise) {
    if (url.isEmpty()) {
      promise.reject("invalid_url", INVALID_URL_MISSING_HTTP)
      return
    }

    try {
      promise.resolve(createCookieArray(readCookies(url)))
    } catch (e: Exception) {
      promise.reject("get_cookie_error", e)
    }
  }

  override fun getCookieHeader(url: String, useWebKit: Boolean?, promise: Promise) {
    if (url.isEmpty()) {
      promise.reject("invalid_url", INVALID_URL_MISSING_HTTP)
      return
    }

    try {
      promise.resolve(readCookieHeader(url) { getCookieManager().getCookie(it) })
    } catch (e: Exception) {
      promise.reject("get_cookie_header_error", e)
    }
  }

  override fun getFromResponse(url: String, promise: Promise) {
    val parsedUrl = try {
      URL(url)
    } catch (e: Exception) {
      promise.reject("invalid_url", INVALID_URL_MISSING_HTTP, e)
      return
    }

    if (parsedUrl.host.isEmpty() || !isHttpScheme(parsedUrl.protocol)) {
      promise.reject("invalid_url", INVALID_URL_MISSING_HTTP)
      return
    }

    NETWORK_EXECUTOR.execute {
      fetchResponseCookies(parsedUrl, promise)
    }
  }

  override fun getAll(useWebKit: Boolean?, promise: Promise) {
    promise.reject("not_supported", GET_ALL_NOT_SUPPORTED)
  }

  override fun getAllAsArray(useWebKit: Boolean?, promise: Promise) {
    promise.reject("not_supported", GET_ALL_NOT_SUPPORTED)
  }

  override fun clearByName(url: String, name: String, useWebKit: Boolean?, promise: Promise) {
    promise.reject("not_supported", CLEAR_BY_NAME_NOT_SUPPORTED)
  }

  override fun clearAll(useWebKit: Boolean?, promise: Promise) {
    clearAllCookies(promise, returnRemovalResult = true)
  }

  override fun clearAllStores(promise: Promise) {
    clearAllCookies(promise, returnRemovalResult = false)
  }

  private fun clearAllCookies(promise: Promise, returnRemovalResult: Boolean) {
    try {
      val cookieManager = getCookieManager()
      cookieManager.removeAllCookies { removed ->
        val result = if (returnRemovalResult) removed else true
        flushAndResolve(cookieManager, result, promise, "clear_all_error")
      }
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

  override fun removeSessionCookies(
    iosClearFoundation: Boolean,
    iosClearWebKit: Boolean,
    promise: Promise
  ) {
    try {
      val cookieManager = getCookieManager()
      cookieManager.removeSessionCookies {
        flushAndResolve(cookieManager, it, promise, "remove_session_error")
      }
    } catch (e: Exception) {
      promise.reject("remove_session_error", e)
    }
  }

  private fun addCookies(url: String, cookieString: String, promise: Promise) {
    try {
      val cookieManager = getCookieManager()
      cookieManager.setCookie(url, cookieString) {
        flushAndResolve(cookieManager, it, promise, "add_cookie_error")
      }
    } catch (e: Exception) {
      promise.reject("add_cookie_error", e)
    }
  }

  private fun flushAndResolve(
    cookieManager: CookieManager,
    result: Any?,
    promise: Promise,
    errorCode: String
  ) {
    PERSISTENCE_EXECUTOR.execute {
      try {
        cookieManager.flush()
        promise.resolve(result)
      } catch (e: Exception) {
        promise.reject(errorCode, e)
      }
    }
  }

  private fun readCookies(url: String): List<ParsedCookie> {
    val cookieManager = getCookieManager()
    val cookieHeaders = readCookieHeaders(
      supportsDetailedRead = WebViewFeature.isFeatureSupported(WebViewFeature.GET_COOKIE_INFO),
      detailedReader = { CookieManagerCompat.getCookieInfo(cookieManager, url) },
      legacyReader = { cookieManager.getCookie(url) }
    )
    return parseCookieReadResult(cookieHeaders)
  }

  private fun createCookieList(cookies: List<ParsedCookie>): WritableMap {
    val allCookiesMap = Arguments.createMap()

    for (cookie in cookies) {
      allCookiesMap.putMap(cookie.name, createCookieMap(cookie))
    }

    return allCookiesMap
  }

  private fun createCookieArray(cookies: List<ParsedCookie>): WritableArray {
    val cookieArray = Arguments.createArray()
    for (cookie in cookies) {
      cookieArray.pushMap(createCookieMap(cookie))
    }
    return cookieArray
  }

  private fun createCookieMap(cookie: ParsedCookie): WritableMap {
    val cookieMap = Arguments.createMap()
    cookieMap.putString("name", cookie.name)
    cookieMap.putString("value", cookie.value)
    cookieMap.putString("domain", cookie.domain)
    cookieMap.putString("path", cookie.path)
    cookieMap.putBoolean("secure", cookie.secure)
    cookieMap.putBoolean("httpOnly", cookie.httpOnly)
    cookie.expiresAt?.let { expiresAt ->
      formatDate(Date(expiresAt))?.let { expires ->
        cookieMap.putString("expires", expires)
      }
    }
    return cookieMap
  }

  private fun fetchResponseCookies(
    url: URL,
    promise: Promise
  ) {
    var currentUrl = url
    var redirectCount = 0
    var storedRedirectCookies = false

    try {
      while (true) {
        var connection: HttpURLConnection? = null
        try {
          connection = currentUrl.openConnection() as HttpURLConnection
          connection.requestMethod = "GET"
          connection.instanceFollowRedirects = false
          connection.connectTimeout = FETCH_TIMEOUT_MILLISECONDS
          connection.readTimeout = FETCH_TIMEOUT_MILLISECONDS

          val requestCookieHeader = getCookieManager().getCookie(currentUrl.toString())
          if (!requestCookieHeader.isNullOrEmpty()) {
            connection.setRequestProperty("Cookie", requestCookieHeader)
          }

          // Accessing the status code performs the request. HTTP error statuses
          // are still valid responses and may contain Set-Cookie headers.
          val responseCode = connection.responseCode
          val setCookieHeaders = getSetCookieHeaders(connection)
          val redirectUrl = getRedirectUrl(currentUrl, connection, responseCode)

          if (redirectUrl != null) {
            if (redirectCount >= MAX_REDIRECTS) {
              throw ProtocolException("Too many redirects: ${redirectCount + 1}")
            }

            // Apply redirect cookies before selecting cookies for the next URL.
            // The callback confirms that WebView's cookie store has been updated.
            storeResponseCookiesAndWait(currentUrl, setCookieHeaders)
            storedRedirectCookies = storedRedirectCookies || setCookieHeaders.isNotEmpty()
            currentUrl = redirectUrl
            redirectCount += 1
            continue
          }

          val responseCookies = parseResponseCookies(setCookieHeaders, currentUrl)
          reactApplicationContext.runOnUiQueueThread {
            storeResponseCookies(
              currentUrl,
              setCookieHeaders,
              responseCookies,
              shouldFlush = storedRedirectCookies || setCookieHeaders.isNotEmpty(),
              promise = promise
            )
          }
          return
        } finally {
          connection?.disconnect()
        }
      }
    } catch (e: Exception) {
      promise.reject("get_from_response_error", e)
    }
  }

  private fun getSetCookieHeaders(connection: HttpURLConnection): List<String> =
    connection.headerFields
      .filterKeys { key -> key != null && isSetCookieHeader(key) }
      .values
      .flatten()

  private fun getRedirectUrl(
    currentUrl: URL,
    connection: HttpURLConnection,
    responseCode: Int
  ): URL? {
    if (!isRedirectStatus(responseCode)) {
      return null
    }

    val location = connection.getHeaderField("Location") ?: return null
    val redirectUrl = URL(currentUrl, location)
    if (redirectUrl.host.isEmpty() || !isHttpScheme(redirectUrl.protocol)) {
      throw ProtocolException("Unsupported redirect URL: $redirectUrl")
    }
    return redirectUrl
  }

  private fun storeResponseCookiesAndWait(url: URL, headers: List<String>) {
    if (headers.isEmpty()) {
      return
    }

    val completionLatch = CountDownLatch(headers.size)
    val storeError = AtomicReference<Exception?>(null)

    reactApplicationContext.runOnUiQueueThread {
      try {
        val cookieManager = getCookieManager()
        for (header in headers) {
          try {
            cookieManager.setCookie(url.toString(), header) {
              completionLatch.countDown()
            }
          } catch (e: Exception) {
            storeError.compareAndSet(null, e)
            completionLatch.countDown()
          }
        }
      } catch (e: Exception) {
        storeError.compareAndSet(null, e)
        while (completionLatch.count > 0) {
          completionLatch.countDown()
        }
      }
    }

    if (!completionLatch.await(FETCH_TIMEOUT_MILLISECONDS.toLong(), TimeUnit.MILLISECONDS)) {
      throw SocketTimeoutException("Timed out while storing redirect cookies")
    }
    storeError.get()?.let { throw it }
  }

  private fun parseResponseCookies(headers: List<String>, responseUrl: URL): List<ResponseCookie> {
    val parsedCookies = mutableListOf<ResponseCookie>()
    val parsedAt = System.currentTimeMillis()
    val defaultPath = defaultCookiePath(responseUrl)

    for (header in headers) {
      val cookies = try {
        HttpCookie.parse(header)
      } catch (e: IllegalArgumentException) {
        Log.i(NAME, e.message ?: "Unable to parse Set-Cookie header")
        continue
      }

      for (cookie in cookies) {
        val expiresAt = if (cookie.maxAge >= 0) {
          try {
            Math.addExact(parsedAt, Math.multiplyExact(cookie.maxAge, 1000L))
          } catch (_: ArithmeticException) {
            null
          }
        } else {
          null
        }

        parsedCookies.add(
          ResponseCookie(
            name = cookie.name,
            value = cookie.value,
            domain = cookie.domain ?: responseUrl.host,
            path = cookie.path ?: defaultPath,
            version = cookie.version.toString(),
            expiresAt = expiresAt,
            secure = cookie.secure,
            httpOnly = HTTP_ONLY_SUPPORTED && cookie.isHttpOnly
          )
        )
      }
    }

    return parsedCookies
  }

  private fun storeResponseCookies(
    responseUrl: URL,
    headers: List<String>,
    cookies: List<ResponseCookie>,
    shouldFlush: Boolean,
    promise: Promise
  ) {
    val result = createResponseCookieList(cookies)
    if (!shouldFlush) {
      promise.resolve(result)
      return
    }

    var settled = false
    try {
      val cookieManager = getCookieManager()
      if (headers.isEmpty()) {
        flushAndResolve(cookieManager, result, promise, "get_from_response_error")
        return
      }

      var remaining = headers.size

      for (header in headers) {
        cookieManager.setCookie(responseUrl.toString(), header) {
          remaining -= 1
          if (remaining == 0 && !settled) {
            settled = true
            flushAndResolve(cookieManager, result, promise, "get_from_response_error")
          }
        }
      }
    } catch (e: Exception) {
      if (!settled) {
        settled = true
        promise.reject("get_from_response_error", e)
      }
    }
  }

  private fun createResponseCookieList(cookies: List<ResponseCookie>): WritableMap {
    val result = Arguments.createMap()

    for (cookie in cookies) {
      val cookieMap = Arguments.createMap()
      cookieMap.putString("name", cookie.name)
      cookieMap.putString("value", cookie.value)
      cookieMap.putString("domain", cookie.domain)
      cookieMap.putString("path", cookie.path)
      cookieMap.putString("version", cookie.version)
      cookieMap.putBoolean("secure", cookie.secure)
      cookieMap.putBoolean("httpOnly", cookie.httpOnly)
      cookie.expiresAt?.let { expiresAt ->
        formatDate(Date(expiresAt))?.let { expires ->
          cookieMap.putString("expires", expires)
        }
      }
      result.putMap(cookie.name, cookieMap)
    }

    return result
  }

  private fun defaultCookiePath(url: URL): String {
    val path = url.path
    if (path.isNullOrEmpty() || !path.startsWith('/')) {
      return "/"
    }

    val lastSlash = path.lastIndexOf('/')
    return if (lastSlash <= 0) "/" else path.substring(0, lastSlash)
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

      if (domain != null && !domainMatches(topLevelDomain, domain)) {
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

  private fun getCookieManager(): CookieManager {
    val cookieManager = CookieManager.getInstance()
    cookieManager.setAcceptCookie(true)
    return cookieManager
  }

  private fun isEmpty(value: String?): Boolean {
    return value == null || value.isEmpty()
  }

  private fun domainMatches(host: String, domain: String): Boolean {
    val normalizedHost = host.lowercase(Locale.US)
    val normalizedDomain = domain.lowercase(Locale.US)

    return normalizedDomain.isNotEmpty() &&
      (normalizedHost == normalizedDomain || normalizedHost.endsWith(".$normalizedDomain"))
  }

  private fun isHttpScheme(scheme: String): Boolean =
    scheme.equals("http", ignoreCase = true) || scheme.equals("https", ignoreCase = true)

  private fun isSetCookieHeader(name: String): Boolean =
    name.equals("Set-Cookie", ignoreCase = true) ||
      name.equals("Set-Cookie2", ignoreCase = true)

  private fun isRedirectStatus(statusCode: Int): Boolean =
    statusCode == HttpURLConnection.HTTP_MULT_CHOICE ||
      statusCode == HttpURLConnection.HTTP_MOVED_PERM ||
      statusCode == HttpURLConnection.HTTP_MOVED_TEMP ||
      statusCode == HttpURLConnection.HTTP_SEE_OTHER ||
      statusCode == HTTP_TEMPORARY_REDIRECT ||
      statusCode == HTTP_PERMANENT_REDIRECT

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

  private data class ResponseCookie(
    val name: String,
    val value: String,
    val domain: String,
    val path: String,
    val version: String,
    val expiresAt: Long?,
    val secure: Boolean,
    val httpOnly: Boolean
  )

  companion object {
    private const val INVALID_URL_MISSING_HTTP =
      "Invalid URL: It may be missing a protocol (ex. http:// or https://)."
    private const val INVALID_COOKIE_VALUES = "Unable to add cookie - invalid values"
    private const val GET_ALL_NOT_SUPPORTED = "Get all cookies not supported for Android (iOS only)"
    private const val CLEAR_BY_NAME_NOT_SUPPORTED = "Cannot remove a single cookie by name on Android"
    private const val INVALID_DOMAINS =
      "Cookie URL host %s and domain %s mismatched. The cookie won't set correctly."
    private const val FETCH_TIMEOUT_MILLISECONDS = 60_000
    private const val MAX_REDIRECTS = 20
    private const val HTTP_TEMPORARY_REDIRECT = 307
    private const val HTTP_PERMANENT_REDIRECT = 308

    private val USES_LEGACY_STORE = Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP
    private val HTTP_ONLY_SUPPORTED = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N
    private val NETWORK_EXECUTOR = Executors.newCachedThreadPool()
    private val PERSISTENCE_EXECUTOR = Executors.newSingleThreadExecutor()

    const val NAME = "CookieManager"
  }
}
