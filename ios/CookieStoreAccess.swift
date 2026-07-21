import Foundation
import WebKit

enum CookieStoreKind {
  case foundation
  case webKit
}

enum CookieStoreAccess {
  static func set(
    _ cookie: HTTPCookie,
    in store: CookieStoreKind,
    completion: @escaping () -> Void
  ) {
    switch store {
    case .foundation:
      HTTPCookieStorage.shared.setCookie(cookie)
      completion()
    case .webKit:
      guard #available(iOS 11.0, macOS 10.13, *) else {
        completion()
        return
      }
      DispatchQueue.main.async {
        WKWebsiteDataStore.default().httpCookieStore.setCookie(
          cookie,
          completionHandler: completion
        )
      }
    }
  }

  static func loadAll(
    from store: CookieStoreKind,
    completion: @escaping ([HTTPCookie]) -> Void
  ) {
    switch store {
    case .foundation:
      completion(HTTPCookieStorage.shared.cookies ?? [])
    case .webKit:
      guard #available(iOS 11.0, macOS 10.13, *) else {
        completion([])
        return
      }
      DispatchQueue.main.async {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies(completion)
      }
    }
  }

  static func load(
    for url: URL,
    from store: CookieStoreKind,
    domainMatches: @escaping (
      _ originDomain: String,
      _ cookieDomain: String
    ) -> Bool,
    completion: @escaping ([HTTPCookie]) -> Void
  ) {
    switch store {
    case .foundation:
      completion(HTTPCookieStorage.shared.cookies(for: url) ?? [])
    case .webKit:
      guard let host = url.host, !host.isEmpty else {
        completion([])
        return
      }
      loadAll(from: .webKit) { cookies in
        completion(
          cookies.filter { cookie in
            domainMatches(host, cookie.domain)
          }
        )
      }
    }
  }

  static func delete(
    _ cookie: HTTPCookie,
    from store: CookieStoreKind,
    completion: @escaping () -> Void
  ) {
    switch store {
    case .foundation:
      HTTPCookieStorage.shared.deleteCookie(cookie)
      completion()
    case .webKit:
      guard #available(iOS 11.0, macOS 10.13, *) else {
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
  }

  static func clearAll(
    from store: CookieStoreKind,
    completion: @escaping () -> Void
  ) {
    switch store {
    case .foundation:
      let storage = HTTPCookieStorage.shared
      storage.cookies?.forEach { storage.deleteCookie($0) }
      completion()
    case .webKit:
      guard #available(iOS 11.0, macOS 10.13, *) else {
        completion()
        return
      }
      DispatchQueue.main.async {
        WKWebsiteDataStore.default().removeData(
          ofTypes: [WKWebsiteDataTypeCookies],
          modifiedSince: Date(timeIntervalSince1970: 0),
          completionHandler: completion
        )
      }
    }
  }
}
