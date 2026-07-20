# @preeternal/react-native-cookie-manager
[![npm version](https://img.shields.io/npm/v/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)
[![npm downloads](https://img.shields.io/npm/dm/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)

A modern, New Architecture–ready Cookie Manager for React Native. This is a drop-in replacement for @react-native-cookies/cookies, rewritten with TypeScript, TurboModules, and platform-native implementations for iOS (Swift) and Android (Kotlin).

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
import axios from 'axios';
import CookieManager from '@preeternal/react-native-cookie-manager';

const url = 'https://example.com/login';
await axios.get(url);
// Fetch alternative: await fetch(url);
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

// Clear all cookies
await CookieManager.clearAll();

// Android only: persist cookies to storage
await CookieManager.flush();

// Android only: remove session cookies (cookies without an expiry date)
await CookieManager.removeSessionCookies();
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

| Method | Returns | Description |
| --- | --- | --- |
| `set(url, cookie, useWebKit?)` | `Promise<boolean>` | Stores a cookie. |
| `get(url, useWebKit?)` | `Promise<Cookies>` | Reads stored cookies matching the URL; makes no request. |
| `clearAll(useWebKit?)` | `Promise<boolean>` | Clears the selected cookie store. |
| `getAll(useWebKit?)` | `Promise<Cookies>` | Reads all cookies (iOS; rejects on Android). |
| `clearByName(url, name, useWebKit?)` | `Promise<boolean>` | Clears matching cookies by name (iOS; rejects on Android). |
| `flush()` | `Promise<void>` | Persists cookies to storage (Android; no-op on iOS). |
| `removeSessionCookies()` | `Promise<boolean>` | Removes cookies without an expiry date (Android; returns `false` on iOS). |
| `setFromResponse(url, cookieHeader)` | `Promise<boolean>` | Imports one raw `Set-Cookie` header value. |
| `getFromResponse(url)` | `Promise<Cookies>` | Deprecated; performs a GET and returns cookies from the final response. |

`useWebKit` applies only to iOS (switches to `WKHTTPCookieStore`); on Android it is ignored because WebView and native share a single cookie store.

### WebKit on iOS

- iOS has two stores: `NSHTTPCookieStorage` (used by URLSession) and `WKHTTPCookieStore` (used by WKWebView / `react-native-webview`).
- Pass `useWebKit: true` when you need cookies to sync with WKWebView. For network-only flows, omit it to use `NSHTTPCookieStorage`.
- If your app mixes both (native requests and embedded web), call the same operation twice: once with `useWebKit: true` (for WKWebView), once with `useWebKit: false` (for URLSession).
- On Android the flag is ignored; WebView and native use the same store.

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

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
