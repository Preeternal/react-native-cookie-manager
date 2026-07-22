enum CookieCollectionLogic {
  static func asArray<Element>(
    _ elements: [Element],
    transform: (Element) -> [String: Any]
  ) -> [[String: Any]] {
    elements.map(transform)
  }

  static func asDictionary<Element>(
    _ elements: [Element],
    name: (Element) -> String,
    transform: (Element) -> [String: Any]
  ) -> [String: Any] {
    var result: [String: Any] = [:]
    for element in elements {
      result[name(element)] = transform(element)
    }
    return result
  }
}
