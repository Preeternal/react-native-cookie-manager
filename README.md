# @preeternal/react-native-cookie-manager
[![npm version](https://img.shields.io/npm/v/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)
[![npm downloads](https://img.shields.io/npm/dm/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)

A modern, New Architecture–ready Cookie Manager for React Native. This is a drop-in replacement for `@react-native-cookies/cookies`, rewritten with TypeScript, TurboModules, and platform-native implementations for iOS (Swift) and Android (Kotlin).

## Upstream / credits

This package is based on the public API and behavior of [`@react-native-cookies/cookies`](https://github.com/react-native-cookies/cookies). Big thanks to the upstream maintainers and contributors for the original implementation and long-term work on the project.

## Installation

### Using Bun

```bash
bun add @preeternal/react-native-cookie-manager
```

### Using yarn

```bash
yarn add @preeternal/react-native-cookie-manager
```

### Using npm

```bash
npm install @preeternal/react-native-cookie-manager
```

Then install iOS pods:

```sh
cd ios && bundle exec pod install
```

Supports both old (bridged) and New Architecture (TurboModule) builds out of the box. Works in bare RN apps and in Expo Dev Builds (custom native build).

### AndroidX WebKit version

Android uses `androidx.webkit:webkit:1.16.0` by default. Most applications do not need to configure it. Bare React Native apps can override the requested version in `android/gradle.properties`:

```properties
react_native_cookie_manager_webkit_version=1.16.0
```

Alternatively, an existing shared override in the root `android/build.gradle` is honored, including when it also configures `react-native-webview`:

```gradle
rootProject.ext.webkitVersion = "1.16.0"
```

The package-specific `gradle.properties` value takes precedence when both are present.

Expo apps can configure the same property during prebuild:

```json
{
  "expo": {
    "plugins": [
      [
        "@preeternal/react-native-cookie-manager",
        { "androidWebkitVersion": "1.16.0" }
      ]
    ]
  }
}
```

Versions older than `1.6.0` are unsupported because the library compiles against `CookieManagerCompat.getCookieInfo()`. Gradle may select a higher compatible version when another dependency requires it.

## Usage

### After a network request

React Native stores response cookies automatically. Make the request with your HTTP client, then read cookies matching the URL:

```ts
import CookieManager from '@preeternal/react-native-cookie-manager';

const url = 'https://example.com/login';
await fetch(url);
// axios alternative: await axios(url);
const cookies = await CookieManager.get(url);
```

Standard React Native networking handles cookies by default. Credentials options are only needed if your client configuration explicitly disables cookie handling. `get()` only reads the native cookie store; it does not make a request.

If a custom client or Axios adapter does not use React Native's native cookie handling, `getCookieHeader(url)` returns a ready-to-use `Cookie` request-header value. Do not add it to standard Fetch/Axios requests, where native networking already attaches cookies.

The upstream-compatible `getFromResponse(url)` remains available but is deprecated: it performs a separate GET, follows redirects, and updates the cookie store without options for headers, authentication, timeout, or cancellation. Prefer the flow above to avoid a duplicate request and its side effects.

### Manage the cookie store

```ts
await CookieManager.set('https://example.com', {
  name: 'session',
  value: 'abc123',
  domain: 'example.com',
  path: '/',
  secure: true,
  httpOnly: true,
  sameSite: 'lax',
  maxAge: 60 * 60 * 24 * 7,
});

const cookies = await CookieManager.get('https://example.com');

// Preserve cookies that share a name but differ by domain or path
const cookieVariants = await CookieManager.getAsArray('https://example.com');

// iOS only: get all cookies
const allCookies = await CookieManager.getAll();

// Clear cookies named "session"
await CookieManager.clearByName('https://example.com', 'session');

// Clear Foundation on iOS; clear the shared store on Android
await CookieManager.clearAll();

// Clear Foundation and the default WebKit store on iOS
await CookieManager.clearAllStores();

// Remove session cookies from both iOS stores; shared Android store
await CookieManager.removeSessionCookies();

// iOS: limit session cleanup to one store when needed
await CookieManager.removeSessionCookies({ iosCookieStore: 'webKit' });
```

All methods return Promises and reject when an operation fails.

### Import a Set-Cookie header

`setFromResponse()` is an advanced API for importing a raw `Set-Cookie` header from a custom HTTP client that does not share React Native's cookie store. It is normally unnecessary with Fetch or Axios. Call it once for each `Set-Cookie` header value.

```ts
await CookieManager.setFromResponse(
  'https://example.com',
  'session=abc123; Path=/; Secure; HttpOnly'
);
```

## API

The public API remains compatible with `@react-native-cookies/cookies`.

| Method | Platforms | Description |
| --- | --- | --- |
| `set(url, cookie, useWebKit?)`: `Promise<boolean>` | iOS, Android | Stores a cookie, including `sameSite` and relative `maxAge`. On iOS, uses Foundation by default or default WebKit when `true`. |
| `get(url, useWebKit?)`: `Promise<Cookies>` | iOS, Android | Reads matching cookies without making a request. On iOS, uses Foundation by default or default WebKit when `true`. |
| `getAsArray(url, useWebKit?)`: `Promise<ReadonlyArray<Cookie>>` | iOS, Android | Reads matching cookies without collapsing cookies that share a name. Store selection matches `get()`. |
| `getCookieHeader(url, useWebKit?)`: `Promise<string>` | iOS, Android | Returns the selected store's matching cookies as a `Cookie` request-header value, or an empty string. |
| `clearAll(useWebKit?)`: `Promise<boolean>` | iOS, Android | Clears the shared Android store. On iOS, clears Foundation by default or default WebKit when `true`. |
| `clearAllStores()`: `Promise<boolean>` | iOS, Android | Clears the shared Android store, or Foundation and default WebKit on iOS; resolves `true` after native completion. |
| `getAll(useWebKit?)`: `Promise<Cookies>` | iOS | Reads Foundation by default or default WebKit when `true`. |
| `getAllAsArray(useWebKit?)`: `Promise<ReadonlyArray<Cookie>>` | iOS | Reads the selected iOS store without collapsing cookies that share a name. |
| `clearByName(url, name, useWebKit?)`: `Promise<boolean>` | iOS, Android | Clears same-name cookies from the selected iOS store, or variants applicable to `url` in the shared Android store. |
| `flush()`: `Promise<void>` | iOS, Android | Explicit persistence barrier for the Android store; normally unnecessary after library mutations. It is a no-op on iOS because the system manages persistence automatically. |
| `removeSessionCookies(options?)`: `Promise<boolean>` | iOS, Android | Removes cookies without an expiry date and reports whether any were removed; includes both iOS stores by default. |
| `setFromResponse(url, cookieHeader)`: `Promise<boolean>` | iOS, Android | Imports one raw `Set-Cookie` header value; uses Foundation on iOS. |
| `getFromResponse(url)`: `Promise<Cookies>` | iOS, Android | Deprecated; performs a GET and updates Foundation on iOS. |

`useWebKit` is available on `set()`, `get()`, `getAsArray()`, `getCookieHeader()`, `clearAll()`, `getAll()`, `getAllAsArray()`, and `clearByName()`. On iOS, omitted/`false` selects Foundation and `true` selects only the default WebKit store; it never combines them. On Android the flag is ignored because WebView and native share a single store.

`removeSessionCookies()` clears both iOS stores by default. Pass `{ iosCookieStore: 'foundation' }` or `{ iosCookieStore: 'webKit' }` to limit cleanup to one store. Android ignores this iOS-only option.

On Android, `clearByName()` relies on `GET_COOKIE_INFO` support in the device's Android System WebView provider. It rejects with `not_supported` on devices with an older provider. The method clears every same-name domain/path variant visible to the supplied URL. A cookie restricted to `/account` is not visible from a `/` URL, so use a matching path (and multiple calls for unrelated paths). On iOS, the method clears same-domain variants across all paths in the selected store.

### Cookie shape

```ts
type Cookie = {
  name: string;
  value: string;
  path?: string;
  domain?: string;
  version?: string;
  expires?: string; // ISO 8601 string, e.g. 2015-05-30T12:30:00.00-05:00
  secure?: boolean;
  httpOnly?: boolean;
  sameSite?: 'lax' | 'strict' | 'none';
  maxAge?: number; // set() only: relative lifetime in whole seconds
};
```

`maxAge` takes precedence over `expires`; `0` or a negative value expires the cookie immediately. Native stores expose the resulting absolute `expires` date when reading, not the original `maxAge`. `sameSite: 'none'` requires `secure: true`. The iOS `HTTPCookie` model represents this unrestricted policy as no explicit SameSite value, so reads may omit `sameSite` after setting `'none'`.

`partitioned` is intentionally not a structured field: creating a partitioned cookie requires top-level site context that this API's cookie URL cannot express consistently across Android and iOS. Prefer receiving it from the server or setting it inside the relevant WebView context.

`Cookies` is keyed by cookie name, so `get()` and `getAll()` retain only the last item when multiple cookies share a name. This legacy behavior is preserved for upstream compatibility. Use `getAsArray()` or `getAllAsArray()` when `domain`/`path` variants must remain separate.

On Android, metadata is populated when the device's Android System WebView provider supports `GET_COOKIE_INFO`. Devices with an older provider fall back to legacy name/value parsing, so `domain`, `path`, `expires`, and `sameSite` may be unavailable, while `secure` and `httpOnly` should not be treated as authoritative.

### WebKit on iOS

- iOS has two stores: `NSHTTPCookieStorage` (used by URLSession) and `WKHTTPCookieStore` (used by WKWebView / `react-native-webview`).
- Pass `useWebKit: true` to operate on the default WKWebView cookie store. For network-only flows, omit it to use `NSHTTPCookieStorage`.
- To apply `set()` or `clearByName()` to both stores, call the method once with `useWebKit: false` and once with `true`. Reading both stores with `get()`, `getAsArray()`, `getCookieHeader()`, `getAll()`, or `getAllAsArray()` likewise requires two calls; results are returned separately and are not merged.
- `getCookieHeader(url, true)` filters default WebKit cookies by domain, path, `Secure`, and expiry. A URL alone cannot reproduce WebKit's `SameSite`, partition, or third-party request context, so do not treat it as the exact header of an embedded WebView request.
- Use `clearAllStores()` when logout must clear both app-accessible stores. The library cannot access a non-persistent or custom store owned by a specific WebView.
- On Android the flag is ignored; WebView and native use the same store.

> [!WARNING]
> On Android, `react-native-webview`'s `incognito` mode currently clears the shared app-wide cookie store, including cookies used by React Native networking. Avoid it when your app relies on authenticated native requests. See [react-native-webview#3988](https://github.com/react-native-webview/react-native-webview/issues/3988).

### Persistence and expiration

- A cookie is persistent only when the server supplies `Expires`/`Max-Age`, or when `set()` receives `expires`/`maxAge`. Native stores enforce expiration; `flush()` does not extend a cookie's lifetime or turn a session cookie into a persistent one.
- On iOS, Foundation and WebKit manage persistence automatically. There is no public explicit flush API, so `flush()` is a no-op.
- On Android, the library automatically flushes the shared WebView cookie store after its mutations. Current WebView implementations may also restore session cookies—cookies without an expiry—after a process restart.

On Android, mutation methods automatically flush before their Promises resolve. Calling `flush()` immediately after awaiting `set()`, `setFromResponse()`, `getFromResponse()`, `clearByName()`, `clearAll()`, `clearAllStores()`, or `removeSessionCookies()` is redundant. Use it only as an explicit persistence barrier after the shared Android store was changed outside this library.

The library intentionally does not maintain a separate cookie backup or silently replay cookies on startup. That could resurrect expired or logged-out authentication state and would require the application to choose appropriate secure storage. Prefer server-defined persistent cookies; call `removeSessionCookies()` before the first request or WebView load when the application requires a clean session on launch.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
