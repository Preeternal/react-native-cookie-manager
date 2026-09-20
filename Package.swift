// swift-tools-version: 6.0

import Foundation
import PackageDescription

let isSwiftTestPackage = ProcessInfo.processInfo.environment["COOKIE_MANAGER_SWIFT_TESTS"] == "1"

let helperSources = [
  "CookieChangeObserver.swift",
  "CookieAttributeLogic.swift",
  "CookieCollectionLogic.swift",
  "CookieDomainLogic.swift",
  "CookieHeaderLogic.swift",
  "CookieSessionLogic.swift",
  "CookieStoreAccess.swift",
  "CookieStoreClearLogic.swift",
]

let package: Package

if isSwiftTestPackage {
  package = Package(
    name: "CookieManagerSwiftTests",
    platforms: [
      .iOS(.v15),
      .macOS(.v12),
    ],
    products: [],
    targets: [
      .target(
        name: "CookieChangeObserver",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieChangeObserver.swift"
        },
        sources: ["CookieChangeObserver.swift"]
      ),
      .target(
        name: "CookieDomainLogic",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieDomainLogic.swift"
        },
        sources: ["CookieDomainLogic.swift"]
      ),
      .target(
        name: "CookieSessionLogic",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieSessionLogic.swift"
        },
        sources: ["CookieSessionLogic.swift"]
      ),
      .target(
        name: "CookieStoreClearLogic",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieStoreClearLogic.swift"
        },
        sources: ["CookieStoreClearLogic.swift"]
      ),
      .target(
        name: "CookieCollectionLogic",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieCollectionLogic.swift"
        },
        sources: ["CookieCollectionLogic.swift"]
      ),
      .target(
        name: "CookieStoreAccess",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieStoreAccess.swift"
        },
        sources: ["CookieStoreAccess.swift"]
      ),
      .target(
        name: "CookieHeaderLogic",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieHeaderLogic.swift"
        },
        sources: ["CookieHeaderLogic.swift"]
      ),
      .target(
        name: "CookieAttributeLogic",
        path: "ios",
        exclude: ["CookieManager.swift", "ReactNative"] + helperSources.filter {
          $0 != "CookieAttributeLogic.swift"
        },
        sources: ["CookieAttributeLogic.swift"]
      ),
      .testTarget(
        name: "CookieChangeObserverTests",
        dependencies: ["CookieChangeObserver"],
        path: "swift-tests/CookieChangeObserverTests"
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
      .testTarget(
        name: "CookieHeaderLogicTests",
        dependencies: ["CookieHeaderLogic"],
        path: "swift-tests/CookieHeaderLogicTests"
      ),
      .testTarget(
        name: "CookieAttributeLogicTests",
        dependencies: ["CookieAttributeLogic"],
        path: "swift-tests/CookieAttributeLogicTests"
      ),
    ],
    swiftLanguageModes: [.v5]
  )
} else {
  let reactHeaders: [Target.Dependency] = [
    .product(name: "ReactHeaders", package: "ReactNative"),
    .product(name: "ReactNativeHeaders", package: "ReactNative"),
    .product(name: "ReactNativeDependenciesHeaders", package: "ReactNative"),
    .product(name: "ReactAppHeaders", package: "React-GeneratedCode"),
  ]

  package = Package(
    name: "ReactNativeCookieManager",
    platforms: [.iOS(.v15)],
    products: [
      .library(
        name: "ReactNativeCookieManager",
        targets: ["ReactNativeCookieManager"]
      ),
    ],
    dependencies: [
      // React Native's SPM autolinker exposes this package through
      // ios/build/generated/autolinking/libs/ReactNativeCookieManager.
      .package(name: "ReactNative", path: "../../../../xcframeworks"),
      .package(name: "React-GeneratedCode", path: "../../../ios"),
    ],
    targets: [
      .target(
        name: "CookieManagerImplementation",
        dependencies: reactHeaders,
        path: "ios",
        exclude: ["ReactNative"],
        sources: ["CookieManager.swift"] + helperSources,
        linkerSettings: [
          .linkedFramework("Foundation"),
          .linkedFramework("WebKit"),
        ]
      ),
      .target(
        name: "ReactNativeCookieManager",
        dependencies: ["CookieManagerImplementation"] + reactHeaders,
        path: "ios/ReactNative",
        sources: ["CookieManager.mm"],
        publicHeadersPath: ".",
        cSettings: [
          .headerSearchPath("."),
        ],
        cxxSettings: [
          .headerSearchPath("."),
          .unsafeFlags([
            "-DFOLLY_NO_CONFIG",
            "-DFOLLY_MOBILE=1",
            "-DFOLLY_USE_LIBCPP=1",
            "-DFOLLY_CFG_NO_COROUTINES=1",
            "-DFOLLY_HAVE_CLOCK_GETTIME=1",
            "-Wno-comma",
            "-Wno-shorten-64-to-32",
            "-DRN_FABRIC_ENABLED",
            "-fno-modules",
          ]),
          .define("DEBUG", .when(configuration: .debug)),
          .define("NDEBUG", .when(configuration: .release)),
          .define("RCT_NEW_ARCH_ENABLED", to: "1"),
          .define("RCT_REMOVE_LEGACY_ARCH", to: "1"),
        ],
        linkerSettings: [
          .linkedFramework("Foundation"),
          .linkedFramework("WebKit"),
        ]
      ),
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx20
  )
}
