import Foundation

enum CookieManagerErrorCode: String, CaseIterable {
  case invalidURL = "invalid_url"
  case invalidCookie = "invalid_cookie"
  case domainMismatch = "domain_mismatch"
  case notSupported = "not_supported"
  case storageError = "storage_error"
  case networkError = "network_error"
}

struct CookieManagerInputError: LocalizedError {
  let code: CookieManagerErrorCode
  let message: String
  let underlyingError: Error?

  init(
    code: CookieManagerErrorCode,
    message: String,
    underlyingError: Error? = nil
  ) {
    self.code = code
    self.message = message
    self.underlyingError = underlyingError
  }

  var errorDescription: String? { message }
}
