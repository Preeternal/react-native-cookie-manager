// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "CookieManagerSwiftTests",
  platforms: [
    .macOS(.v12),
  ],
  products: [],
  targets: [
    .target(
      name: "CookieDomainLogic",
      path: "ios",
      exclude: [
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieStoreClearLogic.swift",
        "CookieSessionLogic.swift",
      ],
      sources: ["CookieDomainLogic.swift"]
    ),
    .target(
      name: "CookieSessionLogic",
      path: "ios",
      exclude: [
        "CookieDomainLogic.swift",
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieStoreClearLogic.swift",
      ],
      sources: ["CookieSessionLogic.swift"]
    ),
    .target(
      name: "CookieStoreClearLogic",
      path: "ios",
      exclude: [
        "CookieDomainLogic.swift",
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieSessionLogic.swift",
      ],
      sources: ["CookieStoreClearLogic.swift"]
    ),
    .testTarget(
      name: "CookieDomainLogicTests",
      dependencies: ["CookieDomainLogic"],
      path: "swift-tests/CookieDomainLogicTests"
    ),
    .testTarget(
      name: "CookieSessionLogicTests",
      dependencies: ["CookieSessionLogic"],
      path: "swift-tests/CookieSessionLogicTests"
    ),
    .testTarget(
      name: "CookieStoreClearLogicTests",
      dependencies: ["CookieStoreClearLogic"],
      path: "swift-tests/CookieStoreClearLogicTests"
    ),
  ]
)
