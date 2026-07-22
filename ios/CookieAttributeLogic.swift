import Foundation

enum CookieAttributeLogic {
  static func apply(
    props: NSDictionary,
    secure: Bool,
    to cookieProperties: inout [HTTPCookiePropertyKey: Any],
    parseDate: (String) -> Date?
  ) throws {
    if let rawMaxAge = props["maxAge"], !(rawMaxAge is NSNull) {
      cookieProperties[.maximumAge] = try maxAgeString(from: rawMaxAge)
    } else if let expires = props["expires"] as? String, let date = parseDate(expires) {
      cookieProperties[.expires] = date
    }

    guard let rawSameSite = props["sameSite"], !(rawSameSite is NSNull) else {
      return
    }
    guard let sameSite = rawSameSite as? String else {
      throw CookieAttributeError.invalidSameSite
    }

    switch sameSite.lowercased() {
    case "lax", "strict":
      guard #available(iOS 13.0, macOS 10.15, *) else {
        throw CookieAttributeError.sameSiteUnavailable
      }
      cookieProperties[.sameSitePolicy] = sameSite.lowercased()
    case "none":
      guard secure else {
        throw CookieAttributeError.insecureSameSiteNone
      }
      // Foundation represents an unrestricted cross-site cookie with a nil
      // policy and ignores an explicit "none" value.
    default:
      throw CookieAttributeError.invalidSameSite
    }
  }

  static func sameSiteValue(from cookie: HTTPCookie) -> String? {
    guard #available(iOS 13.0, macOS 10.15, *) else {
      return nil
    }
    guard let value = cookie.sameSitePolicy?.rawValue.lowercased() else {
      return nil
    }
    return ["lax", "strict", "none"].contains(value) ? value : nil
  }

  private static func maxAgeString(from rawValue: Any) throws -> String {
    guard
      let number = rawValue as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID()
    else {
      throw CookieAttributeError.invalidMaxAge
    }

    let value = number.doubleValue
    guard
      value.isFinite,
      value.rounded(.towardZero) == value,
      abs(value) <= 9_007_199_254_740_991
    else {
      throw CookieAttributeError.invalidMaxAge
    }

    return String(Int64(value))
  }
}

private enum CookieAttributeError: LocalizedError {
  case invalidMaxAge
  case invalidSameSite
  case insecureSameSiteNone
  case sameSiteUnavailable

  var errorDescription: String? {
    switch self {
    case .invalidMaxAge:
      return "maxAge must be a finite safe integer number of seconds"
    case .invalidSameSite:
      return "sameSite must be \"lax\", \"strict\", or \"none\""
    case .insecureSameSiteNone:
      return "SameSite \"none\" requires secure: true"
    case .sameSiteUnavailable:
      return "SameSite requires iOS 13 or newer"
    }
  }
}
