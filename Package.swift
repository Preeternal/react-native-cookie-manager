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
      exclude: ["CookieManager.h", "CookieManager.mm", "CookieManager.swift"],
      sources: ["CookieDomainLogic.swift"]
    ),
    .testTarget(
      name: "CookieDomainLogicTests",
      dependencies: ["CookieDomainLogic"],
      path: "swift-tests/CookieDomainLogicTests"
    ),
  ]
)
