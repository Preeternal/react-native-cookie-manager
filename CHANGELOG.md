# Releases

---

## v6.4.0 (Unreleased)

### Fixed

- Android `getFromResponse()` now performs the inherited GET request instead of returning the input URL.
- Android applies `Set-Cookie` before each redirect and selects stored cookies for every destination URL instead of forwarding the original `Cookie` header.
- Both platforms return the declared `Cookies` object shape and update their native cookie store.
- On iOS, `getFromResponse()` values are now `Cookie` objects instead of raw strings; read the cookie value through `.value`. This aligns runtime behavior with the existing TypeScript contract.
- Awaiting Android `set()`, `setFromResponse()`, or `clearAll()` now guarantees that its automatic `flush()` has completed, so an immediate app shutdown or restart cannot leave the previous cookie state on disk. The blocking persistence work runs on a worker thread.
- Awaiting iOS `clearByName(url, name, true)` now waits for every matching WebKit deletion, preventing a following request or WebView load from observing cookies that were still being removed.
- Android `get(url)` now returns stored `domain`, `path`, `expires`, `secure`, and `httpOnly` attributes when the installed WebView supports `GET_COOKIE_INFO`. Older WebViews transparently retain the previous name/value-only behavior.

### Tests

- Added Android unit coverage for the detailed cookie read, both fallback paths, empty results, attribute parsing, expiration precedence/conversion, and legacy behavior.

### Compatibility

- Android now depends on `androidx.webkit:webkit:1.16.0` (`minSdk 24`, `compileSdk 33+`, and Android Gradle Plugin 7.2+); the library defaults remain `minSdk 24`, `compileSdk 36`, and AGP 8.7.2.

### Deprecated

- `getFromResponse()` is deprecated but retained for compatibility with `@react-native-cookies/cookies`; no removal version is scheduled.
- Prefer making requests with Fetch/Axios and reading the shared native store with `get(url)`. This avoids a duplicate request and leaves request configuration with the application.

### Documentation

- Documented the network and cookie-store side effects of the legacy API.
- Added a concise Fetch/Axios response flow and clarified the advanced `setFromResponse()` use case.

---

## v6.3.3: Strict cookie domain validation

This release fixes inherited cookie domain validation behavior that accepted substring matches instead of RFC-style domain matches.

### Fixed

- Android now rejects invalid cookie domains such as `example.com` for `https://notexample.com`.
- iOS uses the same exact-or-parent-domain validation when setting cookies.
- Domain validation remains case-insensitive and continues to allow exact hosts and valid parent domains.

### Tests

- Added Swift regression coverage for substring domain mismatches such as `notexample.com` and `badexample.com`.

Fixes #3

---

## v6.3.2: React Native 0.85 template refresh

This release refreshes the project scaffold and example app to the latest `create-react-native-library` template. The public CookieManager API and native cookie behavior are unchanged.

### Compatibility

- JavaScript API remains compatible with `@react-native-cookies/cookies`.
- Android minimum SDK remains `24` (Android 7.0).
- React Native development and example app baseline updated to `0.85.0`.
- React development baseline updated to `19.2.3`.
- Old Architecture compatibility remains available for older React Native versions that still support it.
- Old Architecture support is deprecated and will be removed in a future major release.

### Android

- Updated the example Android project to the current React Native 0.85 template.
- Updated example Gradle wrapper to `9.3.1`.
- Updated library Android defaults to `compileSdkVersion 36` and `targetSdkVersion 36`.
- Moved library Android default versions into `android/build.gradle` and removed the separate library `android/gradle.properties`.
- Migrated Android lint configuration from `lintOptions` to `lint`.
- Kept the native Kotlin CookieManager implementation and JS API behavior unchanged.

### iOS

- Updated the example iOS project and pods for React Native 0.85.
- Enabled React Native prebuilt dependencies in CI for faster iOS builds.
- Preserved the existing Swift/Objective-C CookieManager implementation and bridge exports.

### Tooling and CI

- Updated `create-react-native-library` metadata from `0.55.1` to `0.62.0`.
- Updated Node tooling to Node 24 in `.nvmrc` and publish workflows.
- Updated TypeScript, ESLint, Prettier, Turbo, and Bob dependencies to match the refreshed template.
- Added an Expo Android prebuild smoke test to CI.
- Added iOS build log upload on CI failures for easier diagnostics.
- Removed Jest, Lefthook, Commitlint, and Release It from the local template tooling.

---

## v6.3.1: iOS subdomain cookie fix + regression tests

This release fixes iOS cookie domain handling issues affecting WebView and subdomains.

### Fixed (iOS)

- Preserve leading-dot domains when setting cookies on iOS (`.example.com`).
- Validate domains without mutating the original cookie domain value.
- Use consistent domain matching for WebKit cookie reads (`get(url, true)`).
- import RCTBridgeModule only for old architecture builds to avoid architecture-specific integration issues.

### Tests and CI

- Added Swift regression tests for domain normalization, validation, and subdomain matching.
- Added `swift test` execution in the macOS CI pipeline.

### Example app

- Added manual domain input flow for cookie testing.
- Each new submission adds a new cookie and refreshes available cookies from shared/WebKit stores.

Fixes #2

---

## v6.3.0 – Full TurboModule Rewrite (Swift/Kotlin, NA-Ready)

- Rebuilt CookieManager as a TurboModule with Swift (iOS) and Kotlin (Android) native implementations; JS API stays compatible (set/get etc.).
- Renamed native methods to setCookie/getCookies to avoid Android codegen clashes; old-arch bridge exports added on iOS to match.
- Android: cleaned up legacy CookieSyncManager path (minSdk 24), suppressed deprecation noise.
- iOS: unified bridge import of CookieManager-Swift.h; supports both old and new arch from a single module.
- Docs: expanded README (install via yarn/npm/bun + pod install, WebKit guidance, cookie shape, usage with try/catch)
- Old architecture support kept intact on both platforms (iOS bridge exports and Android module still work with the classic architecture).
