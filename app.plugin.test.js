const assert = require('node:assert/strict');
const Module = require('node:module');
const test = require('node:test');

const originalLoad = Module._load;
Module._load = function loadWithConfigPluginsMock(request, parent, isMain) {
  if (request === '@expo/config-plugins') {
    return {
      createRunOncePlugin: (plugin) => plugin,
      withAndroidGradleProperties: (config, action) => {
        const mod = {
          modResults: config.androidGradleProperties || [],
        };
        const result = action(mod);
        config.androidGradleProperties = result.modResults;
        return config;
      },
    };
  }

  return originalLoad(request, parent, isMain);
};

let plugin;
try {
  plugin = require('./app.plugin.js');
} finally {
  Module._load = originalLoad;
}

test('does not write the default when the option is omitted', () => {
  const config = {};

  assert.equal(plugin(config), config);
  assert.equal(config.androidGradleProperties, undefined);
});

test('adds and updates the AndroidX WebKit Gradle property', () => {
  const config = {};

  plugin(config, { androidWebkitVersion: '1.15.0' });
  plugin(config, { androidWebkitVersion: '1.16.0' });

  assert.deepEqual(config.androidGradleProperties, [
    {
      type: 'property',
      key: 'react_native_cookie_manager_webkit_version',
      value: '1.16.0',
    },
  ]);
});

test('accepts AndroidX prerelease versions above the minimum', () => {
  const config = {};

  plugin(config, { androidWebkitVersion: '1.17.0-alpha01' });

  assert.equal(config.androidGradleProperties[0].value, '1.17.0-alpha01');
});

test('rejects malformed and unsupported versions', () => {
  assert.throws(
    () => plugin({}, { androidWebkitVersion: 'latest' }),
    /Expected a full version/
  );
  assert.throws(
    () => plugin({}, { androidWebkitVersion: '1.5.0' }),
    /must be 1\.6\.0 or newer/
  );
  assert.throws(
    () => plugin({}, { androidWebkitVersion: '1.6.0-alpha01' }),
    /must be 1\.6\.0 or newer/
  );
});
