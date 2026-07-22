import Foundation

enum CookieSessionLogic {
  static func isSessionCookie(_ cookie: HTTPCookie) -> Bool {
    cookie.isSessionOnly || cookie.expiresDate == nil
  }

  static func sessionCookies(
    from cookies: [HTTPCookie],
    enabled: Bool = true
  ) -> [HTTPCookie] {
    guard enabled else { return [] }
    return cookies.filter(isSessionCookie)
  }

  static func removeSessionCookies(
    foundationCookies: [HTTPCookie],
    clearFoundation: Bool,
    clearWebKit: Bool,
    deleteFoundation: (_ cookie: HTTPCookie) -> Void,
    loadWebKitCookies: (_ completion: @escaping ([HTTPCookie]) -> Void) -> Void,
    deleteWebKitCookie: @escaping (
      _ cookie: HTTPCookie,
      _ completion: @escaping () -> Void
    ) -> Void,
    completion: @escaping (_ removed: Bool) -> Void
  ) {
    let foundationSessionCookies = sessionCookies(
      from: foundationCookies,
      enabled: clearFoundation
    )
    for cookie in foundationSessionCookies {
      deleteFoundation(cookie)
    }
    let removedFromFoundation = !foundationSessionCookies.isEmpty

    guard clearWebKit else {
      completion(removedFromFoundation)
      return
    }

    loadWebKitCookies { webKitCookies in
      removeSessionCookies(
        from: webKitCookies,
        delete: deleteWebKitCookie
      ) { removedFromWebKit in
        completion(removedFromFoundation || removedFromWebKit)
      }
    }
  }

  static func removeSessionCookies(
    from cookies: [HTTPCookie],
    delete: (_ cookie: HTTPCookie, _ completion: @escaping () -> Void) -> Void,
    completion: @escaping (_ removed: Bool) -> Void
  ) {
    let sessionCookies = sessionCookies(from: cookies)
    guard !sessionCookies.isEmpty else {
      completion(false)
      return
    }

    let deletionGroup = DispatchGroup()
    for cookie in sessionCookies {
      deletionGroup.enter()
      delete(cookie) {
        deletionGroup.leave()
      }
    }

    deletionGroup.notify(queue: .main) {
      completion(true)
    }
  }
}
