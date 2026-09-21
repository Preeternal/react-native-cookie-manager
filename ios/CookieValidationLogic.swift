import Foundation

enum CookieValidationLogic {
  static func validateStructuredStrings(
    name: String,
    value: String,
    domain: String?,
    path: String?,
    version: String?,
    expires: String?,
    sameSite: String?,
    validate: Bool,
    parseDate: (String) -> Date?
  ) throws {
    guard !name.isEmpty else {
      throw CookieValidationError.invalid("Cookie name must not be empty")
    }

    let fields: [(String, String?)] = [
      ("name", name),
      ("value", value),
      ("domain", domain),
      ("path", path),
      ("version", version),
      ("expires", expires),
      ("sameSite", sameSite),
    ]
    for (field, fieldValue) in fields {
      if let fieldValue, containsASCIIControlCharacter(fieldValue) {
        throw CookieValidationError.invalid(
          "Cookie \(field) must not contain control characters"
        )
      }
    }

    guard !name.contains("=") && !name.contains(";") else {
      throw CookieValidationError.invalid(
        "Cookie name must not contain \"=\" or \";\""
      )
    }
    guard !value.contains(";") else {
      throw CookieValidationError.invalid(
        "Cookie value must not contain \";\" because native stores treat it as an attribute separator"
      )
    }
    guard domain?.contains(";") != true else {
      throw CookieValidationError.invalid("Cookie domain must not contain \";\"")
    }
    guard path?.contains(";") != true else {
      throw CookieValidationError.invalid("Cookie path must not contain \";\"")
    }

    guard validate else { return }

    guard isPortableCookieName(name) else {
      throw CookieValidationError.invalid(
        "Cookie name contains characters unsupported by native stores"
      )
    }
    if let path, !path.isEmpty, !path.hasPrefix("/") {
      throw CookieValidationError.invalid("Cookie path must start with \"/\"")
    }
    if let expires, !expires.isEmpty, parseDate(expires) == nil {
      throw CookieValidationError.invalid(
        "Cookie expires must be a valid ISO 8601 date"
      )
    }
  }

  static func validateRawSetCookieHeader(_ cookie: String) throws {
    guard !cookie.isEmpty else {
      throw CookieValidationError.invalid("Cookie header must not be empty")
    }
    let containsHeaderTerminator = cookie.unicodeScalars.contains { scalar in
      scalar.value == 0 || scalar.value == 10 || scalar.value == 13
    }
    guard !containsHeaderTerminator else {
      throw CookieValidationError.invalid(
        "Cookie header must not contain CR, LF, or NUL"
      )
    }
  }

  private static func containsASCIIControlCharacter(_ value: String) -> Bool {
    value.unicodeScalars.contains { scalar in
      scalar.value <= 0x1F || scalar.value == 0x7F
    }
  }

  private static func isPortableCookieName(_ name: String) -> Bool {
    guard !name.hasPrefix("$") else { return false }

    let punctuation = "!#$%&'*+-.^_`|~"
    return name.unicodeScalars.allSatisfy { scalar in
      switch scalar.value {
      case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
        return true
      default:
        return scalar.isASCII && punctuation.unicodeScalars.contains(scalar)
      }
    }
  }
}

private enum CookieValidationError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case let .invalid(message): message
    }
  }
}
