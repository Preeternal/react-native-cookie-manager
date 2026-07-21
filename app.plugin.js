const pkg = require('./package.json');

let configPlugins;
try {
  configPlugins = require('@expo/config-plugins');
} catch (error) {
  const errorCode = error && error.code;
  if (errorCode !== 'MODULE_NOT_FOUND') {
    throw error;
  }
  configPlugins = require('expo/config-plugins');
}

const { createRunOncePlugin } = configPlugins;
const withAndroidGradleProperties =
  typeof configPlugins.withAndroidGradleProperties === 'function'
    ? configPlugins.withAndroidGradleProperties
    : configPlugins.withGradleProperties;

if (typeof withAndroidGradleProperties !== 'function') {
  throw new Error(
    `${pkg.name}: incompatible Expo config-plugins API (missing Android Gradle properties helper).`
  );
}

const PROPERTY_KEY = 'react_native_cookie_manager_webkit_version';
const MINIMUM_VERSION = [1, 6, 0];
const VERSION_PATTERN = /^(\d+)\.(\d+)\.(\d+)((?:[-+][0-9A-Za-z.-]+)?)$/;

function normalizeAndroidWebkitVersion(rawVersion) {
  if (rawVersion == null) {
    return null;
  }

  const version = String(rawVersion).trim();
  const match = VERSION_PATTERN.exec(version);
  if (!match) {
    throw new Error(
      `${pkg.name}: invalid androidWebkitVersion '${rawVersion}'. Expected a full version such as '1.16.0'.`
    );
  }

  const parts = match.slice(1, 4).map(Number);
  const suffix = match[4];
  const isTooOld =
    parts[0] < MINIMUM_VERSION[0] ||
    (parts[0] === MINIMUM_VERSION[0] && parts[1] < MINIMUM_VERSION[1]) ||
    (parts.every((part, index) => part === MINIMUM_VERSION[index]) &&
      suffix.startsWith('-'));

  if (isTooOld) {
    throw new Error(
      `${pkg.name}: androidWebkitVersion must be 1.6.0 or newer (got '${version}').`
    );
  }

  return version;
}

function withCookieManagerWebkitVersion(config, props = {}) {
  const version = normalizeAndroidWebkitVersion(props.androidWebkitVersion);
  if (version == null) {
    return config;
  }

  return withAndroidGradleProperties(config, (mod) => {
    const existing = mod.modResults.find(
      (item) => item.type === 'property' && item.key === PROPERTY_KEY
    );

    if (existing) {
      existing.value = version;
    } else {
      mod.modResults.push({
        type: 'property',
        key: PROPERTY_KEY,
        value: version,
      });
    }

    return mod;
  });
}

module.exports = createRunOncePlugin(
  withCookieManagerWebkitVersion,
  pkg.name,
  pkg.version
);
