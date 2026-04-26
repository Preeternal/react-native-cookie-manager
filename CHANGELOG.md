# Releases

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
