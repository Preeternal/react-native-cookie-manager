import Foundation

enum CookieHeaderLogic {
  static func headerValue(for cookies: [HTTPCookie]) -> String {
    let fields = HTTPCookie.requestHeaderFields(with: cookies)
    return fields.first { key, _ in
      key.caseInsensitiveCompare("Cookie") == .orderedSame
    }?.value ?? ""
  }

  static func matchingWebKitCookies(
    for url: URL,
    from cookies: [HTTPCookie],
    now: Date = Date()
  ) -> [HTTPCookie] {
    guard let host = url.host, !host.isEmpty else {
      return []
    }

    let requestPath = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    )?.percentEncodedPath.nonEmpty ?? "/"
    let scheme = url.scheme?.lowercased()
    let secureRequest = scheme == "https" || scheme == "wss"

    return cookies.enumerated()
      .filter { _, cookie in
        domainMatches(host: host, cookieDomain: cookie.domain) &&
          pathMatches(requestPath: requestPath, cookiePath: cookie.path) &&
          (!cookie.isSecure || secureRequest) &&
          (cookie.expiresDate.map { $0 > now } ?? true)
      }
      .sorted { lhs, rhs in
        let lhsLength = lhs.element.path.utf8.count
        let rhsLength = rhs.element.path.utf8.count
        return lhsLength == rhsLength ? lhs.offset < rhs.offset : lhsLength > rhsLength
      }
      .map(\.element)
  }

  private static func domainMatches(host: String, cookieDomain: String) -> Bool {
    let normalizedHost = host.lowercased()
    let normalizedDomain = cookieDomain.lowercased()

    guard normalizedDomain.hasPrefix(".") else {
      return normalizedHost == normalizedDomain
    }

    let parentDomain = String(normalizedDomain.dropFirst())
    return !parentDomain.isEmpty &&
      (normalizedHost == parentDomain || normalizedHost.hasSuffix(".\(parentDomain)"))
  }

  private static func pathMatches(requestPath: String, cookiePath: String) -> Bool {
    let normalizedCookiePath = cookiePath.isEmpty ? "/" : cookiePath

    if requestPath == normalizedCookiePath {
      return true
    }
    guard requestPath.hasPrefix(normalizedCookiePath) else {
      return false
    }
    if normalizedCookiePath.hasSuffix("/") {
      return true
    }

    let boundaryIndex = requestPath.index(
      requestPath.startIndex,
      offsetBy: normalizedCookiePath.count
    )
    return boundaryIndex < requestPath.endIndex && requestPath[boundaryIndex] == "/"
  }
}

private extension String {
  var nonEmpty: String? {
    isEmpty ? nil : self
  }
}
