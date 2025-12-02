# @preeternal/react-native-cookie-manager
[![npm version](https://img.shields.io/npm/v/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)
[![npm downloads](https://img.shields.io/npm/dm/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)

A modern, New Architecture–ready Cookie Manager for React Native. This is a drop-in replacement for @react-native-cookies/cookies, rewritten with TypeScript, TurboModules, and platform-native implementations for iOS (Swift) and Android (Kotlin).

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

```ts
import CookieManager from '@preeternal/react-native-cookie-manager';

// Set a cookie
try {
  await CookieManager.set('https://example.com', {
    name: 'session',
    value: 'abc123',
    domain: 'example.com',
    path: '/',
    secure: true,
    httpOnly: true,
  });

  // Set cookies from a Set-Cookie header
  await CookieManager.setFromResponse(
    'https://example.com',
    'user_session=abcdefg; path=/; expires=Thu, 1 Jan 2030 00:00:00 -0000; secure; HttpOnly'
  );

  // Get cookies for a URL
  const cookies = await CookieManager.get('https://example.com');

  // iOS only: get all cookies
  const allCookies = await CookieManager.getAll();

  // Clear by name (iOS only)
  await CookieManager.clearByName('https://example.com', 'session');

  // Clear everything
  await CookieManager.clearAll();

  // Android only: persist to storage
  await CookieManager.flush();

  // Android only: remove session cookies (no expires)
  await CookieManager.removeSessionCookies();
} catch (err) {
  console.warn('Cookie operation failed', err);
}
```

## API (compatible with @react-native-cookies/cookies)

- `set(url, cookie, useWebKit?)`
- `setFromResponse(url, cookieHeader)`
- `get(url, useWebKit?)`
- `getFromResponse(url)`
- `clearAll(useWebKit?)`
- `flush()` — Android
- `removeSessionCookies()` — Android
- `getAll(useWebKit?)` — iOS
- `clearByName(url, name, useWebKit?)` — iOS

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
