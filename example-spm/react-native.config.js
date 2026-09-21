const path = require('path');
const pkg = require('../package.json');

module.exports = {
  dependencies: {
    [pkg.name]: {
      root: path.join(__dirname, '..'),
      platforms: {
        // Keep both platforms explicit: React Native codegen otherwise skips
        // the local workspace package before native autolinking runs.
        ios: {},
        android: {},
      },
    },
  },
};
