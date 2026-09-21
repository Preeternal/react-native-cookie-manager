# Swift Package Manager example

This podless React Native 0.87 app exercises the local workspace package through
React Native's experimental SwiftPM autolinking. Its application screen matches
the CocoaPods example so the two integration paths exercise the same public API.

## Run it

From the repository root:

```sh
yarn install
yarn example:spm ios
```

The `ios` and `build:ios` scripts regenerate the ignored SwiftPM autolinking
output before invoking Xcode, so they also work after a fresh clone and in CI.
To run on a specific simulator or device, open
`example-spm/ios/CookieManagerExampleSpm.xcodeproj` after generation.

The initial CocoaPods-to-SwiftPM migration is already committed; do not run
`react-native spm --deintegrate` in this example again. Its `ios/Podfile` is only
a React Native CLI project-discovery stub and deliberately fails if somebody
runs `pod install`.

React Native 0.87.1 currently writes a machine-specific `HERMES_CLI_PATH` while
generating the project. The setup script removes it from committed Xcode files
after each refresh.

## What the app demonstrates

- local-package resolution through React Native autolinking and Metro, without
  a `file:..` dependency;
- named Foundation/WebKit store selection and an iOS invalidation example that
  reads one matching cookie, the changed store, and both store snapshots;
- stable error codes, structured validation, raw header import, cleanup, and
  duplicate-preserving reads;
- the same native smoke and persistence checks as the CocoaPods example.

The device smoke test clears this example app's cookie stores. Do not point the
example at stores containing data you need to keep.
