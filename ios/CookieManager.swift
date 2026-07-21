import Foundation
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
      CookieStoreAccess.set(cookie, in: .webKit) { resolve(true) }
    } else {
      CookieStoreAccess.set(cookie, in: .foundation) { resolve(true) }
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
      CookieStoreAccess.set(cookieItem, in: .foundation) {}
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
        CookieStoreAccess.set(cookie, in: .foundation) {}
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
    loadCookies(url: url, useWebKit: useWebKit, reject: reject) { cookies in
      resolve(self.createCookieList(cookies))
    }
  }

  @objc(getAsArray:useWebKit:resolve:reject:)
  public func getAsArray(
    url: NSString,
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    loadCookies(url: url, useWebKit: useWebKit, reject: reject) { cookies in
      resolve(self.createCookieArray(cookies))
    }
  }

  @objc(getCookieHeader:useWebKit:resolve:reject:)
  public func getCookieHeader(
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
      guard parsedUrl.host?.isEmpty == false else {
        reject("invalid_url", Self.invalidURLMissingHTTP, nil)
        return
      }

      CookieStoreAccess.loadAll(from: .webKit) { cookies in
        let matchingCookies = CookieHeaderLogic.matchingWebKitCookies(
          for: parsedUrl,
          from: cookies
        )
        resolve(CookieHeaderLogic.headerValue(for: matchingCookies))
      }
    } else {
      let cookies = HTTPCookieStorage.shared.cookies(for: parsedUrl) ?? []
      resolve(CookieHeaderLogic.headerValue(for: cookies))
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
      clearWebKitCookies {
        resolve(true)
      }
    } else {
      clearFoundationCookies()
      resolve(true)
    }
  }

  @objc(clearAllStoresWithResolve:reject:)
  public func clearAllStores(
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard #available(iOS 11.0, *) else {
      reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
      return
    }

    CookieStoreClearLogic.clearAllStores(
      clearFoundation: {
        self.clearFoundationCookies()
      },
      clearWebKit: { completion in
        self.clearWebKitCookies(completion: completion)
      },
      completion: {
        resolve(true)
      }
    )
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
    if useWebKit {
      guard #available(iOS 11.0, *) else {
        reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
        return
      }
      guard let topLevelDomain = parsedUrl.host, !topLevelDomain.isEmpty else {
        reject("invalid_url", Self.invalidURLMissingHTTP, nil)
        return
      }

      CookieStoreAccess.loadAll(from: .webKit) { allCookies in
        let matchingCookies = allCookies.filter { cookie in
          cookie.name == name &&
            CookieDomainLogic.isMatchingDomain(
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
          CookieStoreAccess.delete(cookie, from: .webKit) {
            deletionGroup.leave()
          }
        }

        deletionGroup.notify(queue: .main) {
          resolve(true)
        }
      }
    } else {
      CookieStoreAccess.loadAll(from: .foundation) { cookies in
        let matchingCookies = cookies.filter { cookie in
          if cookie.name == name,
             let host = parsedUrl.host,
             CookieDomainLogic.isMatchingDomain(originDomain: host, cookieDomain: cookie.domain) {
            return true
          }
          return false
        }
        matchingCookies.forEach { cookie in
          CookieStoreAccess.delete(cookie, from: .foundation) {}
        }
        resolve(!matchingCookies.isEmpty)
      }
    }
  }

  @objc(getAll:resolve:reject:)
  public func getAll(
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    loadAllCookies(useWebKit: useWebKit, reject: reject) { cookies in
      resolve(self.createCookieList(cookies))
    }
  }

  @objc(getAllAsArray:resolve:reject:)
  public func getAllAsArray(
    useWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    loadAllCookies(useWebKit: useWebKit, reject: reject) { cookies in
      resolve(self.createCookieArray(cookies))
    }
  }

  private func loadAllCookies(
    useWebKit: Bool,
    reject: @escaping RCTPromiseRejectBlock,
    completion: @escaping ([HTTPCookie]) -> Void
  ) {
    if useWebKit {
      guard #available(iOS 11.0, *) else {
        reject("web_kit_unavailable", Self.notAvailableErrorMessage, nil)
        return
      }
      CookieStoreAccess.loadAll(from: .webKit, completion: completion)
    } else {
      CookieStoreAccess.loadAll(from: .foundation, completion: completion)
    }
  }

  @objc(flushWithResolve:reject:)
  public func flush(
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(true)
  }

  private func clearFoundationCookies() {
    CookieStoreAccess.clearAll(from: .foundation) {}
  }

  @available(iOS 11.0, *)
  private func clearWebKitCookies(completion: @escaping () -> Void) {
    CookieStoreAccess.clearAll(from: .webKit, completion: completion)
  }

  @objc(removeSessionCookiesWithClearFoundation:clearWebKit:resolve:reject:)
  public func removeSessionCookies(
    clearFoundation: Bool,
    clearWebKit: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    var foundationCookies: [HTTPCookie] = []
    CookieStoreAccess.loadAll(from: .foundation) { foundationCookies = $0 }
    CookieSessionLogic.removeSessionCookies(
      foundationCookies: foundationCookies,
      clearFoundation: clearFoundation,
      clearWebKit: clearWebKit,
      deleteFoundation: { cookie in
        CookieStoreAccess.delete(cookie, from: .foundation) {}
      },
      loadWebKitCookies: { completion in
        guard #available(iOS 11.0, *) else {
          completion([])
          return
        }
        CookieStoreAccess.loadAll(from: .webKit, completion: completion)
      },
      deleteWebKitCookie: { cookie, completion in
        guard #available(iOS 11.0, *) else {
          completion()
          return
        }
        CookieStoreAccess.delete(cookie, from: .webKit, completion: completion)
      }
    ) { removed in
      resolve(removed)
    }
  }

  private func loadCookies(
    url: NSString,
    useWebKit: Bool,
    reject: @escaping RCTPromiseRejectBlock,
    completion: @escaping ([HTTPCookie]) -> Void
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

      guard parsedUrl.host?.isEmpty == false else {
        reject("invalid_url", Self.invalidURLMissingHTTP, nil)
        return
      }

      CookieStoreAccess.load(
        for: parsedUrl,
        from: .webKit,
        domainMatches: CookieDomainLogic.isMatchingDomain,
        completion: completion
      )
    } else {
      CookieStoreAccess.load(
        for: parsedUrl,
        from: .foundation,
        domainMatches: CookieDomainLogic.isMatchingDomain,
        completion: completion
      )
    }
  }

  private func createCookieList(_ cookies: [HTTPCookie]) -> [String: Any] {
    CookieCollectionLogic.asDictionary(
      cookies,
      name: { $0.name },
      transform: createCookieData
    )
  }

  private func createCookieArray(_ cookies: [HTTPCookie]) -> [[String: Any]] {
    CookieCollectionLogic.asArray(cookies, transform: createCookieData)
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
      if !CookieDomainLogic.isMatchingDomain(originDomain: topLevelDomain, cookieDomain: rawDomain) {
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

  private static let notAvailableErrorMessage =
    "WebKit/WebKit-Components are only available with iOS11 and higher!"
  private static let invalidURLMissingHTTP =
    "Invalid URL: It may be missing a protocol (ex. http:// or https://)."
  private static let invalidDomains =
    "Cookie URL host %@ and domain %@ mismatched. The cookie won't set correctly."
}
