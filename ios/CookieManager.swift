import Foundation
import WebKit
import React

@objc(CookieManagerImpl)
public class CookieManagerImpl: NSObject {
  private let formatter: DateFormatter

  public override init() {
    formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    super.init()
  }

  @objc(set:cookie:useWebKit:resolve:reject:)
  public func set(
    url: NSString,
    cookie props: NSDictionary,
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let parsedUrl = URL(string: url as String) else {
      reject("invalid_url", Self.invalidURLMissingHTTP, nil)
      return
    }
    let cookie: HTTPCookie
    do {
      cookie = try makeHTTPCookie(url: parsedUrl, props: props)
    } catch {
      reject("cookie_set_error", error.localizedDescription, error)
      return
    }

    if useWebKit {
      guard #available(iOS 11.0, *) else {
        reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
        return
      }
      DispatchQueue.main.async {
        WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) {
          resolve(true)
        }
      }
    } else {
      HTTPCookieStorage.shared.setCookie(cookie)
      resolve(true)
    }
  }

  @objc(setFromResponse:cookie:resolve:reject:)
  public func setFromResponse(
    url: NSString,
    cookie: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let parsedUrl = URL(string: url as String) else {
      reject("invalid_url", Self.invalidURLMissingHTTP, nil)
      return
    }
    let cookies = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": cookie], for: parsedUrl)
    for cookieItem in cookies {
      HTTPCookieStorage.shared.setCookie(cookieItem)
    }
    resolve(true)
  }

  @objc(getFromResponse:resolve:reject:)
  public func getFromResponse(
    url: NSString,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard
      let parsedUrl = URL(string: url as String),
      let scheme = parsedUrl.scheme?.lowercased(),
      ["http", "https"].contains(scheme),
      parsedUrl.host != nil
    else {
      reject("invalid_url", Self.invalidURLMissingHTTP, nil)
      return
    }
    let request = URLRequest(url: parsedUrl)
    URLSession.shared.dataTask(with: request) { _, response, error in
      if let error {
        reject("get_from_response_error", error.localizedDescription, error)
        return
      }

      guard
        let httpResponse = response as? HTTPURLResponse,
        let headerFields = httpResponse.allHeaderFields as? [String: String]
      else {
        reject("get_from_response_error", "Invalid response", nil)
        return
      }

      let responseURL = httpResponse.url ?? parsedUrl
      let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseURL)
      var result: [String: Any] = [:]
      cookies.forEach { cookie in
        result[cookie.name] = self.createCookieData(cookie)
        HTTPCookieStorage.shared.setCookie(cookie)
      }
      resolve(result)
    }.resume()
  }

  @objc(get:useWebKit:resolve:reject:)
  public func get(
    url: NSString,
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let parsedUrl = URL(string: url as String) else {
      reject("invalid_url", Self.invalidURLMissingHTTP, nil)
      return
    }
    if useWebKit {
      guard #available(iOS 11.0, *) else {
        reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
        return
      }

      guard let topLevelDomain = parsedUrl.host, !topLevelDomain.isEmpty else {
        reject("invalid_url", Self.invalidURLMissingHTTP, nil)
        return
      }

      DispatchQueue.main.async {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { allCookies in
          var cookies: [String: Any] = [:]
          for cookie in allCookies
            where self.isMatchingDomain(originDomain: topLevelDomain, cookieDomain: cookie.domain) {
            cookies[cookie.name] = self.createCookieData(cookie)
          }
          resolve(cookies)
        }
      }
    } else {
      var cookies: [String: Any] = [:]
      let storageCookies = HTTPCookieStorage.shared.cookies(for: parsedUrl) ?? []
      for cookie in storageCookies {
        cookies[cookie.name] = createCookieData(cookie)
      }
      resolve(cookies)
    }
  }

  @objc(clearAll:resolve:reject:)
  public func clearAll(
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    if useWebKit {
      guard #available(iOS 11.0, *) else {
        reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
        return
      }
      DispatchQueue.main.async {
        let websiteDataTypes: Set<String> = [WKWebsiteDataTypeCookies]
        let dateFrom = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(
          ofTypes: websiteDataTypes,
          modifiedSince: dateFrom
        ) {
          resolve(true)
        }
      }
    } else {
      let cookieStorage = HTTPCookieStorage.shared
      cookieStorage.cookies?.forEach { cookieStorage.deleteCookie($0) }
      UserDefaults.standard.synchronize()
      resolve(true)
    }
  }

  @objc(clearByName:name:useWebKit:resolve:reject:)
  public func clearByName(
    url: NSString,
    name: String,
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let parsedUrl = URL(string: url as String) else {
      reject("invalid_url", Self.invalidURLMissingHTTP, nil)
      return
    }
    var found = false
    if useWebKit {
      guard #available(iOS 11.0, *) else {
        reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
        return
      }
      guard let topLevelDomain = parsedUrl.host, !topLevelDomain.isEmpty else {
        reject("invalid_url", Self.invalidURLMissingHTTP, nil)
        return
      }

      DispatchQueue.main.async {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { allCookies in
          let store = WKWebsiteDataStore.default().httpCookieStore
          let matchingCookies = allCookies.filter { cookie in
            cookie.name == name &&
              self.isMatchingDomain(
                originDomain: topLevelDomain,
                cookieDomain: cookie.domain
              )
          }

          guard !matchingCookies.isEmpty else {
            resolve(false)
            return
          }

          let deletionGroup = DispatchGroup()
          for cookie in matchingCookies {
            deletionGroup.enter()
            store.delete(cookie) {
              deletionGroup.leave()
            }
          }

          deletionGroup.notify(queue: .main) {
            resolve(true)
          }
        }
      }
    } else {
      let storage = HTTPCookieStorage.shared
      storage.cookies?.forEach { cookie in
        if cookie.name == name,
           let host = parsedUrl.host,
           self.isMatchingDomain(originDomain: host, cookieDomain: cookie.domain) {
          storage.deleteCookie(cookie)
          found = true
        }
      }
      resolve(found)
    }
  }

  @objc(getAll:resolve:reject:)
  public func getAll(
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    if useWebKit {
      guard #available(iOS 11.0, *) else {
        reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
        return
      }
      DispatchQueue.main.async {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { allCookies in
          resolve(self.createCookieList(allCookies))
        }
      }
    } else {
      let cookies = HTTPCookieStorage.shared.cookies ?? []
      resolve(createCookieList(cookies))
    }
  }

  @objc(flushWithResolve:reject:)
  public func flush(
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(true)
  }

  @objc(removeSessionCookiesWithClearFoundation:clearWebKit:resolve:reject:)
  public func removeSessionCookies(
    clearFoundation: Bool,
    clearWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let storage = HTTPCookieStorage.shared
    CookieSessionLogic.removeSessionCookies(
      foundationCookies: storage.cookies ?? [],
      clearFoundation: clearFoundation,
      clearWebKit: clearWebKit,
      deleteFoundation: { cookie in
        storage.deleteCookie(cookie)
      },
      loadWebKitCookies: { completion in
        guard #available(iOS 11.0, *) else {
          completion([])
          return
        }
        DispatchQueue.main.async {
          WKWebsiteDataStore.default().httpCookieStore.getAllCookies(completion)
        }
      },
      deleteWebKitCookie: { cookie, completion in
        guard #available(iOS 11.0, *) else {
          completion()
          return
        }
        DispatchQueue.main.async {
          WKWebsiteDataStore.default().httpCookieStore.delete(
            cookie,
            completionHandler: completion
          )
        }
      }
    ) { removed in
      resolve(removed)
    }
  }

  private func createCookieList(_ cookies: [HTTPCookie]) -> [String: Any] {
    var cookieList: [String: Any] = [:]
    for cookie in cookies {
      cookieList[cookie.name] = createCookieData(cookie)
    }
    return cookieList
  }

  private func makeHTTPCookie(url: URL, props: NSDictionary) throws -> HTTPCookie {
    guard let topLevelDomain = url.host, !topLevelDomain.isEmpty else {
      throw NSError(domain: "CookieManager", code: -1, userInfo: [NSLocalizedDescriptionKey: Self.invalidURLMissingHTTP])
    }

    guard
      let name = props["name"] as? String,
      let value = props["value"] as? String
    else {
      throw NSError(domain: "CookieManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing name or value"])
    }

    let path = (props["path"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "/"
    var domain = CookieDomainLogic.normalizedInputDomain(props["domain"] as? String)
    let version = props["version"] as? String
    let expires = props["expires"] as? String
    let secure = props["secure"] as? Bool ?? false
    let httpOnly = props["httpOnly"] as? Bool ?? false

    if let rawDomain = domain {
      if !CookieDomainLogic.isCookieDomainValid(host: topLevelDomain, cookieDomain: rawDomain) {
        let reason = String(format: Self.invalidDomains, topLevelDomain, rawDomain)
        throw NSError(domain: "CookieManager", code: -1, userInfo: [NSLocalizedDescriptionKey: reason])
      }
      domain = rawDomain
    } else {
      domain = topLevelDomain
    }

    var cookieProperties: [HTTPCookiePropertyKey: Any] = [
      .name: name,
      .value: value,
      .path: path,
      .domain: domain ?? topLevelDomain,
    ]

    if let version {
      cookieProperties[.version] = version
    }
    if let expires, let date = parseDate(expires) {
      cookieProperties[.expires] = date
    }
    if secure {
      cookieProperties[.secure] = secure
    }
    if httpOnly {
      cookieProperties[HTTPCookiePropertyKey("HttpOnly")] = httpOnly
    }

    if let cookie = HTTPCookie(properties: cookieProperties) {
      return cookie
    }

    throw NSError(domain: "CookieManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create cookie"])
  }

  private func createCookieData(_ cookie: HTTPCookie) -> [String: Any] {
    var cookieData: [String: Any] = [
      "name": cookie.name,
      "value": cookie.value,
      "path": cookie.path,
      "domain": cookie.domain,
      "version": "\(cookie.version)",
      "secure": cookie.isSecure,
      "httpOnly": cookie.isHTTPOnly,
    ]

    if let expiresDate = cookie.expiresDate {
      cookieData["expires"] = formatter.string(from: expiresDate)
    }

    return cookieData
  }

  private func parseDate(_ dateString: String) -> Date? {
    formatter.date(from: dateString)
  }

  private func isMatchingDomain(originDomain: String, cookieDomain: String) -> Bool {
    CookieDomainLogic.isMatchingDomain(originDomain: originDomain, cookieDomain: cookieDomain)
  }

  private static let notAvailableErrorMessage =
    "WebKit/WebKit-Components are only available with iOS11 and higher!"
  private static let invalidURLMissingHTTP =
    "Invalid URL: It may be missing a protocol (ex. http:// or https://)."
  private static let invalidDomains =
    "Cookie URL host %@ and domain %@ mismatched. The cookie won't set correctly."
}
