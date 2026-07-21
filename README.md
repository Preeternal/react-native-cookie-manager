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
});

const cookies = await CookieManager.get('https://example.com');

// iOS only: get all cookies
const allCookies = await CookieManager.getAll();

// Clear by name (iOS only)
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

| Method | Platforms | Returns | Description |
| --- | --- | --- | --- |
| `set(url, cookie, useWebKit?)` | iOS, Android | `Promise<boolean>` | Stores a cookie. On iOS, uses Foundation by default or default WebKit when `true`. |
| `get(url, useWebKit?)` | iOS, Android | `Promise<Cookies>` | Reads matching cookies without making a request. On iOS, uses Foundation by default or default WebKit when `true`. |
| `clearAll(useWebKit?)` | iOS, Android | `Promise<boolean>` | Clears the shared Android store. On iOS, clears Foundation by default or default WebKit when `true`. |
| `clearAllStores()` | iOS, Android | `Promise<boolean>` | Clears the shared Android store, or Foundation and default WebKit on iOS; resolves `true` after native completion. |
| `getAll(useWebKit?)` | iOS | `Promise<Cookies>` | Reads Foundation by default or default WebKit when `true`. |
| `clearByName(url, name, useWebKit?)` | iOS | `Promise<boolean>` | Clears matching cookies from Foundation by default or default WebKit when `true`. |
| `flush()` | iOS, Android | `Promise<void>` | Explicit persistence barrier for the Android store; normally unnecessary after library mutations. It is a no-op on iOS because the system manages persistence automatically. |
| `removeSessionCookies(options?)` | iOS, Android | `Promise<boolean>` | Removes cookies without an expiry date and reports whether any were removed; includes both iOS stores by default. |
| `setFromResponse(url, cookieHeader)` | iOS, Android | `Promise<boolean>` | Imports one raw `Set-Cookie` header value; uses Foundation on iOS. |
| `getFromResponse(url)` | iOS, Android | `Promise<Cookies>` | Deprecated; performs a GET and updates Foundation on iOS. |

Exactly five methods accept `useWebKit`: `set()`, `get()`, `clearAll()`, `getAll()`, and `clearByName()`. On iOS, omitted/`false` selects Foundation and `true` selects only the default WebKit store; it never combines them. On Android the flag is ignored because WebView and native share a single store.

`removeSessionCookies()` clears both iOS stores by default. Pass `{ iosCookieStore: 'foundation' }` or `{ iosCookieStore: 'webKit' }` to limit cleanup to one store. Android ignores this iOS-only option.

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
};
```

On Android, metadata is populated when the installed WebView supports `GET_COOKIE_INFO`. Older WebViews fall back to legacy name/value parsing, so `domain`, `path`, and `expires` may be unavailable, while `secure` and `httpOnly` should not be treated as authoritative.

### WebKit on iOS

- iOS has two stores: `NSHTTPCookieStorage` (used by URLSession) and `WKHTTPCookieStore` (used by WKWebView / `react-native-webview`).
- Pass `useWebKit: true` to operate on the default WKWebView cookie store. For network-only flows, omit it to use `NSHTTPCookieStorage`.
- To apply `set()` or `clearByName()` to both stores, call the method once with `useWebKit: false` and once with `true`. Reading both stores with `get()` or `getAll()` likewise requires two calls; results are returned separately and are not merged.
- Use `clearAllStores()` when logout must clear both app-accessible stores. The library cannot access a non-persistent or custom store owned by a specific WebView.
- On Android the flag is ignored; WebView and native use the same store.

> [!WARNING]
> On Android, `react-native-webview`'s `incognito` mode currently clears the shared app-wide cookie store, including cookies used by React Native networking. Avoid it when your app relies on authenticated native requests. See [react-native-webview#3988](https://github.com/react-native-webview/react-native-webview/issues/3988).

### Persistence and expiration

- A cookie is persistent only when the server supplies `Expires`/`Max-Age`, or when `set()` receives `expires`. Native stores enforce expiration; `flush()` does not extend a cookie's lifetime or turn a session cookie into a persistent one.
- On iOS, Foundation and WebKit manage persistence automatically. There is no public explicit flush API, so `flush()` is a no-op.
- On Android, the library automatically flushes the shared WebView cookie store after its mutations. Current WebView implementations may also restore session cookies—cookies without an expiry—after a process restart.

On Android, mutation methods automatically flush before their Promises resolve. Calling `flush()` immediately after awaiting `set()`, `setFromResponse()`, `getFromResponse()`, `clearAll()`, `clearAllStores()`, or `removeSessionCookies()` is redundant. Use it only as an explicit persistence barrier after the shared Android store was changed outside this library.

The library intentionally does not maintain a separate cookie backup or silently replay cookies on startup. That could resurrect expired or logged-out authentication state and would require the application to choose appropriate secure storage. Prefer server-defined persistent cookies; call `removeSessionCookies()` before the first request or WebView load when the application requires a clean session on launch.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
