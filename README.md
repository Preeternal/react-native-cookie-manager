# @preeternal/react-native-cookie-manager
[![npm version](https://img.shields.io/npm/v/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)
[![npm downloads](https://img.shields.io/npm/dm/@preeternal/react-native-cookie-manager.svg)](https://www.npmjs.com/package/@preeternal/react-native-cookie-manager)

A maintained, New Architecture–only cookie manager for React Native, implemented as a TurboModule with Swift on iOS and Kotlin on Android. It is a successor to `@react-native-cookies/cookies`: legacy method names and call signatures remain available, while v7 intentionally changes architecture support, validation, and error codes.

> Starting with `v7.0.0`, this package supports only React Native's New
> Architecture. Projects that still require the legacy bridge should stay
> on `v6.x`.

The package works in bare React Native apps and in Expo Dev Builds (custom native builds).

## Upstream / credits

This package is based on the public API and behavior of [`@react-native-cookies/cookies`](https://github.com/react-native-cookies/cookies). Big thanks to the upstream maintainers and contributors for the original implementation and long-term work on the project.

## Installation

Install with your package manager:

```bash
# Bun
bun add @preeternal/react-native-cookie-manager

# Yarn
yarn add @preeternal/react-native-cookie-manager

# npm
npm install @preeternal/react-native-cookie-manager
```

### CocoaPods (default)

React Native still selects CocoaPods by default. This library keeps its
podspec, so existing apps and React Native versions before 0.87 continue to
install it normally:

```sh
cd ios && bundle exec pod install
```

### Swift Package Manager (React Native 0.87+)

React Native 0.87 added experimental, opt-in SwiftPM integration. This library
ships a compatible `Package.swift`; CocoaPods remains the default and supported
production path.

To migrate an app once:

```sh
cd ios
npx react-native spm --deintegrate
```

After a fresh clone or in CI, generate the SwiftPM workspace before building:

```sh
cd ios
npx react-native spm
```

Every native dependency must have a compatible `Package.swift`. If a dependency
does not provide one, generate it with `npx react-native spm scaffold` and keep
the manifest in a package-manager patch.

The SwiftPM commands and generated layout are experimental in React Native
0.87 and may change in later releases. Do not use this integration in
production yet. See the [React Native 0.87 release notes](https://reactnative.dev/blog/2026/08/11/react-native-0.87#experimental-swift-package-manager-support-for-ios).

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

On iOS, “the WebKit store” below means `WKWebsiteDataStore.default().httpCookieStore`, the app's default persistent store.

```ts
// Foundation on iOS; options are optional
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

// iOS: write to the WebKit store
await CookieManager.set(
  'https://example.com',
  { name: 'web_session', value: 'abc123', path: '/', secure: true },
  { iosCookieStore: 'webKit' }
);

const cookies = await CookieManager.get('https://example.com');

// Preserve cookies that share a name but differ by domain or path
const cookieVariants = await CookieManager.getAsArray('https://example.com');

// iOS only: get all cookies
const allCookies = await CookieManager.getAll();

// Clear cookies named "session"
await CookieManager.clearByName('https://example.com', 'session');

// Clear Foundation on iOS; clear the shared store on Android
await CookieManager.clearAll();

// Clear Foundation and the WebKit store on iOS
await CookieManager.clearAllStores();

// Remove session cookies from both iOS stores; shared Android store
await CookieManager.removeSessionCookies();
await CookieManager.removeSessionCookies({ iosCookieStore: 'both' }); // explicit equivalent

// iOS: limit session cleanup to one store when needed
await CookieManager.removeSessionCookies({ iosCookieStore: 'webKit' });
```

### Observe iOS cookie-store changes

Use the change listener to invalidate application state after Foundation or the WebKit store changes—for example, when a login completes inside a WebView:

```ts
import CookieManager, {
  type IOSCookieStore,
} from '@preeternal/react-native-cookie-manager';
import { useEffect } from 'react';

const url = 'https://example.com/account';

useEffect(() => {
  const subscription = CookieManager.addCookieChangeListener(
    ({ iosCookieStore }) => {
      refreshCookies(iosCookieStore)
        .then((snapshot) => {
          updateAuthState(snapshot);
        })
        .catch((error) => {
          console.error('Failed to refresh cookies after invalidation', error);
        });
    }
  );

  return () => subscription.remove();
}, []);

async function refreshCookies(iosCookieStore: IOSCookieStore) {
  // Read cookies matching one URL from the store that changed.
  const matchingCookies = await CookieManager.get(url, { iosCookieStore });
  const sessionCookie = matchingCookies.session;

  // Or read every cookie in that store.
  const allCookiesInChangedStore = await CookieManager.getAll({
    iosCookieStore,
  });

  // When application state depends on both stores, read them separately.
  const [allFoundationCookies, allWebKitCookies] = await Promise.all([
    CookieManager.getAll({ iosCookieStore: 'foundation' }),
    CookieManager.getAll({ iosCookieStore: 'webKit' }),
  ]);

  return {
    sessionCookie,
    allCookiesInChangedStore,
    allFoundationCookies,
    allWebKitCookies,
  };
}

```

The event payload is only `{ iosCookieStore: 'foundation' | 'webKit' }`. It is an invalidation signal: native stores may coalesce notifications, so one event is not guaranteed for every cookie mutation and no cookie delta is provided. Choose the narrowest useful follow-up read: select one cookie from `get()`, preserve same-name variants with `getAsArray()`, read the changed store with `getAll()` / `getAllAsArray()`, or call those methods once per store when both snapshots are required. Results from Foundation and WebKit remain separate. The listener observes Foundation and the default persistent WebKit store; custom or non-persistent `WKWebsiteDataStore` instances are outside its scope.

Cookie change subscriptions are iOS-only. Calling `addCookieChangeListener()` on Android throws an error with `code: 'not_supported'` because the public Android WebView cookie store has no global change observer.

### Structured validation and v6 migration

`set()` validates the complete structured cookie before touching a native store. Validation is enabled by default on both platforms. It rejects malformed names, paths, and expiry dates, together with control characters or field delimiters that could change the cookie's structure. Printable values do not require percent-encoding or base64url merely because they contain spaces, Unicode, quotes, commas, backslashes, or `=`.

During migration from v6, `{ validate: false }` temporarily restores native-store handling for compatibility-sensitive input. For example, v6 treated an unparseable `expires` value as a session cookie:

```ts
import CookieManager, {
  isCookieManagerError,
  type Cookie,
} from '@preeternal/react-native-cookie-manager';

const cookieFromBackend: Cookie = {
  name: 'session',
  value: '<token supplied by the backend>',
  path: '/',
  // set() requires an ISO 8601 expiry date.
  expires: '2032-06-09 10:18:14 UTC',
};

try {
  await CookieManager.set('https://example.com', cookieFromBackend);
} catch (error) {
  if (isCookieManagerError(error) && error.code === 'invalid_cookie') {
    console.warn('Structured cookie rejected', {
      code: error.code,
      cookieName: cookieFromBackend.name,
      path: cookieFromBackend.path,
      hasExpires: cookieFromBackend.expires !== undefined,
      backendOperation: 'create-session',
    });
  }
}

// Use only after confirming that validation caused the migration failure.
await CookieManager.set('https://example.com', cookieFromBackend, {
  validate: false,
});
```

The `validate` field is deprecated and will be removed in the next major version, when validation becomes unconditional. Do not automatically retry every `invalid_cookie` rejection with validation disabled. Log the stable code and safe source context, fix the producer or backend, and then remove the escape hatch. Never log a cookie value, raw `Set-Cookie` header, authentication token, or session identifier. Messages are diagnostic text and must not be used for branching.

Structural safety checks remain active when `validate: false`. CR, LF, NUL, other ASCII controls, and `;` in a structured value still reject. Android WebView accepts only a raw `Set-Cookie` string and treats the first `;` as an attribute separator, even inside quotes. A literal semicolon therefore cannot be preserved without encoding agreed by the application and backend; the library never encodes values implicitly.

### Import a Set-Cookie header

`setFromResponse()` is an advanced API for importing a raw `Set-Cookie` header from a custom HTTP client that does not share React Native's cookie store. It is normally unnecessary with Fetch or Axios. Call it once for each `Set-Cookie` header value.

```ts
await CookieManager.setFromResponse(
  'https://example.com',
  'session=abc123; Path=/; Secure; HttpOnly'
);
```

Semicolons in this raw API delimit real attributes; they do not escape a literal semicolon inside a value. Empty headers and headers containing CR, LF, or NUL reject before reaching the native store.

## API

Legacy method names and positional boolean overloads remain source-compatible with `@react-native-cookies/cookies`. The New Architecture requirement, default validation, and stable error taxonomy are intentional v7 behavior changes.

| Method | Platforms | Description |
| --- | --- | --- |
| **`addCookieChangeListener(listener)`**: `EventSubscription` | iOS | Subscribes to invalidations from Foundation and the WebKit store. Native observers are shared across JS subscribers and stop after the last subscription is removed. Android throws `not_supported`. |
| **`set(url, cookie, options?)`**: `Promise<boolean>` | iOS, Android | Validates and stores a cookie, including `sameSite` and relative `maxAge`. On iOS, omitted options select Foundation; `{ iosCookieStore: 'webKit' }` selects the WebKit store. `options.validate` is a temporary deprecated v7 migration escape hatch. |
| **`get(url, options?)`**: `Promise<Cookies>` | iOS, Android | Reads matching cookies without making a request. On iOS, omitted options select Foundation; `{ iosCookieStore: 'webKit' }` selects the WebKit store. |
| **`getAsArray(url, options?)`**: `Promise<ReadonlyArray<Cookie>>` | iOS, Android | Reads matching cookies without collapsing cookies that share a name. Store selection matches `get()`. |
| **`getCookieHeader(url, options?)`**: `Promise<string>` | iOS, Android | Returns the selected store's matching cookies as a `Cookie` request-header value, or an empty string. |
| **`clearAll(options?)`**: `Promise<boolean>` | iOS, Android | Clears the shared Android store or the selected iOS store. |
| **`clearAllStores()`**: `Promise<boolean>` | iOS, Android | Clears the shared Android store, or Foundation and the WebKit store on iOS; resolves `true` after native completion. |
| **`getAll(options?)`**: `Promise<Cookies>` | iOS | Reads all cookies from the selected iOS store. |
| **`getAllAsArray(options?)`**: `Promise<ReadonlyArray<Cookie>>` | iOS | Reads the selected iOS store without collapsing cookies that share a name. |
| **`clearByName(url, name, options?)`**: `Promise<boolean>` | iOS, Android | Clears same-name cookies from the selected iOS store, or variants applicable to `url` in the shared Android store. |
| **`flush()`**: `Promise<void>` | iOS, Android | Explicit Android persistence barrier for external shared-store changes. Android mutations already flush automatically; this method is a no-op on iOS. |
| **`removeSessionCookies(options?)`**: `Promise<boolean>` | iOS, Android | Removes cookies without an expiry date and reports whether any were removed; includes both iOS stores by default. |
| **`setFromResponse(url, cookieHeader)`**: `Promise<boolean>` | iOS, Android | Imports one raw `Set-Cookie` header value; uses Foundation on iOS. |
| **`getFromResponse(url)`**: `Promise<Cookies>` | iOS, Android | Deprecated; performs a GET and updates Foundation on iOS. |

All single-store methods use the same optional `{ iosCookieStore }` selector. Omitting options or omitting the field selects Foundation. The legacy positional `useWebKit` overloads remain available throughout v7 but are deprecated; replace `true` with `{ iosCookieStore: 'webKit' }` and `false` with `{ iosCookieStore: 'foundation' }` or omitted options. On iOS each call selects one store and never combines them. Android ignores `iosCookieStore` because WebView and native share a single store.

`removeSessionCookies()` clears both iOS stores by default. Pass `{ iosCookieStore: 'both' }` to state that scope explicitly, or select `'foundation'` / `'webKit'` to limit cleanup to one store. Android ignores this iOS-only option.

On Android, `clearByName()` relies on `GET_COOKIE_INFO` support in the device's Android System WebView provider. It rejects with `not_supported` on devices with an older provider. The method clears every same-name domain/path variant visible to the supplied URL. A cookie restricted to `/account` is not visible from a `/` URL, so use a matching path (and multiple calls for unrelated paths). On iOS, the method clears same-domain variants across all paths in the selected store.

### Error handling

Native failures use a small platform-neutral set of stable codes. Use `isCookieManagerError()` before reading `code`:

```ts
import CookieManager, {
  isCookieManagerError,
} from '@preeternal/react-native-cookie-manager';

try {
  await CookieManager.set(url, cookie);
} catch (error) {
  if (isCookieManagerError(error)) {
    switch (error.code) {
      case 'domain_mismatch':
        // The cookie domain cannot be set from this URL.
        break;
      case 'invalid_cookie':
        // Fix the structured cookie input.
        break;
    }
  }
}
```

| Code | Meaning |
| --- | --- |
| `invalid_url` | The supplied URL failed the parsing or host check required by that operation. |
| `invalid_cookie` | Cookie input cannot be represented or accepted as a cookie. |
| `domain_mismatch` | The cookie domain does not match the URL host or one of its parent domains. |
| `not_supported` | The requested capability is unavailable on this platform or native provider. |
| `storage_error` | The native cookie store could not complete a read, write, deletion, or persistence operation. |
| `network_error` | The deprecated `getFromResponse()` request failed. No other method performs network I/O. |

The human-readable `message` and any native `cause` are diagnostic details and are not stable API. Do not branch on their contents.

v7 does not add a global HTTP(S)-only check to every store operation. URL acceptance otherwise remains delegated to the platform store for compatibility with v6. The deprecated network method still requires an HTTP(S) URL.

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

type IOSCookieStore = 'foundation' | 'webKit';

type IOSCookieStoreOptions = {
  iosCookieStore?: IOSCookieStore;
};

type SetCookieOptions = IOSCookieStoreOptions & {
  /** @deprecated Temporary v7 migration escape hatch. */
  validate?: boolean;
};

type RemoveSessionCookiesOptions = {
  // Defaults to 'both'.
  iosCookieStore?: IOSCookieStore | 'both';
};
```

`maxAge` takes precedence over `expires`; `0` or a negative value expires the cookie immediately. Native stores expose the resulting absolute `expires` date when reading, not the original `maxAge`. `sameSite: 'none'` requires `secure: true`. The iOS `HTTPCookie` model represents this unrestricted policy as no explicit SameSite value, so reads may omit `sameSite` after setting `'none'`.

`partitioned` is intentionally not a structured field: creating a partitioned cookie requires top-level site context that this API's cookie URL cannot express consistently across Android and iOS. Prefer receiving it from the server or setting it inside the relevant WebView context.

`Cookies` is keyed by cookie name, so `get()` and `getAll()` retain only the last item when multiple cookies share a name. This legacy behavior is preserved for upstream compatibility. Use `getAsArray()` or `getAllAsArray()` when `domain`/`path` variants must remain separate.

On Android, metadata is populated when the device's Android System WebView provider supports `GET_COOKIE_INFO`. Devices with an older provider fall back to legacy name/value parsing, so `domain`, `path`, `expires`, and `sameSite` may be unavailable, while `secure` and `httpOnly` should not be treated as authoritative.

### WebKit on iOS

- iOS has two stores: `NSHTTPCookieStorage` (used by URLSession) and `WKHTTPCookieStore` (used by WKWebView / `react-native-webview`).
- Pass `{ iosCookieStore: 'webKit' }` to `set()` to use the default WKWebView cookie store. For network-only flows, omit options or select `'foundation'` to use `NSHTTPCookieStorage`.
- To apply a single-store method to both stores, call it once with `{ iosCookieStore: 'foundation' }` (or omitted options) and once with `{ iosCookieStore: 'webKit' }`. Results are returned separately and are not merged.
- `getCookieHeader(url, { iosCookieStore: 'webKit' })` filters cookies from the WebKit store by domain, path, `Secure`, and expiry. A URL alone cannot reproduce WebKit's `SameSite`, partition, or third-party request context, so do not treat it as the exact header of an embedded WebView request.
- Use `clearAllStores()` when logout must clear both app-accessible stores. The library cannot access a non-persistent or custom store owned by a specific WebView.
- On Android the flag is ignored; WebView and native use the same store.

> [!WARNING]
> On Android, `react-native-webview`'s `incognito` mode currently clears the shared app-wide cookie store, including cookies used by React Native networking. Avoid it when your app relies on authenticated native requests. See [react-native-webview#3988](https://github.com/react-native-webview/react-native-webview/issues/3988).

### AndroidX WebKit version

Android uses `androidx.webkit:webkit:1.16.0` by default. Most applications do not need to configure it. Bare React Native apps can override the requested version in `android/gradle.properties`:

```properties
react_native_cookie_manager_webkit_version=1.16.0
```

An existing shared override in the root `android/build.gradle` is also honored, including when it configures `react-native-webview`:

```gradle
rootProject.ext.webkitVersion = "1.16.0"
```

The package-specific `gradle.properties` value takes precedence when both are present. Expo apps can set it during prebuild:

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

### Persistence and expiration

- A cookie is persistent only when the server supplies `Expires`/`Max-Age`, or when `set()` receives `expires`/`maxAge`. Native stores enforce expiration; `flush()` does not extend a cookie's lifetime or turn a session cookie into a persistent one.
- On iOS, Foundation persistent cookies survive without a WebView. There is no public iOS flush API, so `flush()` is a no-op.
- On Android, the library automatically flushes the shared WebView cookie store after its mutations. Current WebView implementations may also restore session cookies—cookies without an expiry—after a process restart.

A persistent cookie written with `{ iosCookieStore: 'webKit' }` survives process termination only if a normal, non-incognito WKWebView using the default data store was mounted before the process ended. A normally mounted `react-native-webview` satisfies this requirement; installing the package without mounting a WebView does not.

After a cold start, mount the WebView before reading cookies from the previous app session with `get()`, `getAsArray()`, `getCookieHeader()`, `getAll()`, or `getAllAsArray()` using `{ iosCookieStore: 'webKit' }`. Do the same before `clearByName(url, name, { iosCookieStore: 'webKit' })` when deleting a persistent cookie from the previous session, because this method first reads the store to find matching cookies.

Full cleanup with `clearAll({ iosCookieStore: 'webKit' })` or `clearAllStores()` can run before a WebView is mounted because it clears WebKit website data directly. `removeSessionCookies()` can also run before mounting; iOS session cookies are process-scoped and are not expected to survive a restart.

If the app never creates a WebView, use the Foundation store instead by omitting options or selecting `{ iosCookieStore: 'foundation' }`.

On Android, mutation methods automatically flush before their Promises resolve. Calling `flush()` immediately after awaiting `set()`, `setFromResponse()`, `getFromResponse()`, `clearByName()`, `clearAll()`, `clearAllStores()`, or `removeSessionCookies()` is redundant. Use it only as an explicit persistence barrier after the shared Android store was changed outside this library.

The library intentionally does not maintain a separate cookie backup or silently replay cookies on startup. That could resurrect expired or logged-out authentication state and would require the application to choose appropriate secure storage. Prefer server-defined persistent cookies; call `removeSessionCookies()` before the first request or WebView load when the application requires a clean session on launch.

## Examples

- [`example/`](example/) uses CocoaPods on iOS and is also the Android example.
- [`example-spm/`](example-spm/) uses React Native 0.87 SwiftPM autolinking without CocoaPods.

Both apps demonstrate store selection, iOS invalidations, stable errors, structured validation, native smoke checks, and persistence across an app restart.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
