# CocoaPods example

This React Native 0.86 app exercises the local workspace package through its
CocoaPods integration. It is also the Android example app.

## Run it

Install workspace dependencies from the repository root:

```sh
yarn install
```

For iOS, install pods after a fresh clone or native dependency change:

```sh
cd example
bundle install
bundle exec pod install --project-directory=ios
cd ..
```

Start Metro, then run the required platform in another terminal:

```sh
yarn example start
yarn example ios
# or
yarn example android
```

You can also open `example/ios/CookieManagerExample.xcworkspace` in Xcode or
`example/android` in Android Studio.

## What the app demonstrates

- named `iosCookieStore` selection for Foundation and the default persistent
  WebKit store;
- an iOS cookie-change subscription that re-reads the URL from the store named
  by the invalidation event;
- duplicate-name array reads, request-header generation, raw `Set-Cookie`
  import, session cleanup, and stable error codes;
- default structured validation and the temporary v7 `validate: false`
  migration path;
- native device smoke tests and a two-stage persistence check across an app
  restart.

On Android, the screen explains that cookie-change subscriptions are
unsupported instead of attempting to emulate incomplete events.

The device smoke test clears this example app's cookie stores. Do not point the
example at stores containing data you need to keep.
