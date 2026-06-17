import Foundation

enum CookieDomainLogic {
  static func normalizedInputDomain(_ rawDomain: String?) -> String? {
    guard let rawDomain else {
      return nil
    }
    let trimmedDomain = rawDomain.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedDomain.isEmpty ? nil : trimmedDomain
  }

  static func validationDomain(from cookieDomain: String) -> String {
    if cookieDomain.hasPrefix(".") {
      return String(cookieDomain.dropFirst())
    }
    return cookieDomain
  }

  static func isCookieDomainValid(host: String, cookieDomain: String) -> Bool {
    let domainForValidation = validationDomain(from: cookieDomain)
    guard !domainForValidation.isEmpty else {
      return false
    }

    let normalizedHost = host.lowercased()
    let normalizedDomain = domainForValidation.lowercased()
    return normalizedHost == normalizedDomain || normalizedHost.hasSuffix(".\(normalizedDomain)")
  }

  static func isMatchingDomain(originDomain: String, cookieDomain: String) -> Bool {
    if originDomain == cookieDomain {
      return true
    }
    let parentDomain = cookieDomain.hasPrefix(".") ? cookieDomain : ".\(cookieDomain)"
    return originDomain.hasSuffix(parentDomain)
  }
}
