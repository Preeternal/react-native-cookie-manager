import Foundation

enum CookieStoreClearLogic {
  static func clearAllStores(
    clearFoundation: () -> Void,
    clearWebKit: (_ completion: @escaping () -> Void) -> Void,
    completion: @escaping () -> Void
  ) {
    clearFoundation()
    clearWebKit(completion)
  }
}
