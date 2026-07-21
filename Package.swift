// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "CookieManagerSwiftTests",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
  ],
  products: [],
  targets: [
    .target(
      name: "CookieDomainLogic",
      path: "ios",
      exclude: [
        "CookieCollectionLogic.swift",
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieStoreAccess.swift",
        "CookieStoreClearLogic.swift",
        "CookieSessionLogic.swift",
      ],
      sources: ["CookieDomainLogic.swift"]
    ),
    .target(
      name: "CookieSessionLogic",
      path: "ios",
      exclude: [
        "CookieCollectionLogic.swift",
        "CookieDomainLogic.swift",
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieStoreAccess.swift",
        "CookieStoreClearLogic.swift",
      ],
      sources: ["CookieSessionLogic.swift"]
    ),
    .target(
      name: "CookieStoreClearLogic",
      path: "ios",
      exclude: [
        "CookieCollectionLogic.swift",
        "CookieDomainLogic.swift",
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieStoreAccess.swift",
        "CookieSessionLogic.swift",
      ],
      sources: ["CookieStoreClearLogic.swift"]
    ),
    .target(
      name: "CookieCollectionLogic",
      path: "ios",
      exclude: [
        "CookieDomainLogic.swift",
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieSessionLogic.swift",
        "CookieStoreAccess.swift",
        "CookieStoreClearLogic.swift",
      ],
      sources: ["CookieCollectionLogic.swift"]
    ),
    .target(
      name: "CookieStoreAccess",
      path: "ios",
      exclude: [
        "CookieCollectionLogic.swift",
        "CookieDomainLogic.swift",
        "CookieManager.h",
        "CookieManager.mm",
        "CookieManager.swift",
        "CookieSessionLogic.swift",
        "CookieStoreClearLogic.swift",
      ],
      sources: ["CookieStoreAccess.swift"]
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
    .testTarget(
      name: "CookieCollectionLogicTests",
      dependencies: ["CookieCollectionLogic"],
      path: "swift-tests/CookieCollectionLogicTests"
    ),
    .testTarget(
      name: "CookieStoreAccessIntegrationTests",
      dependencies: ["CookieStoreAccess"],
      path: "swift-tests/CookieStoreAccessIntegrationTests"
    ),
  ]
)
