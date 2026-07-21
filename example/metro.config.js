const path = require('path');
const { URL } = require('url');
const { getDefaultConfig } = require('@react-native/metro-config');
const { withMetroConfig } = require('react-native-monorepo-config');

const root = path.resolve(__dirname, '..');

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = withMetroConfig(getDefaultConfig(__dirname), {
  root,
  dirname: __dirname,
});

const defaultEnhanceMiddleware = config.server?.enhanceMiddleware;

config.server = {
  ...config.server,
  enhanceMiddleware: (middleware, server) => {
    const enhancedMiddleware = defaultEnhanceMiddleware
      ? defaultEnhanceMiddleware(middleware, server)
      : middleware;

    return (request, response, next) => {
      const requestURL = new URL(request.url || '/', 'http://localhost');

      if (requestURL.pathname === '/__cookie_manager_smoke__') {
        const value = requestURL.searchParams.get('value');
        if (!value || !/^\d+$/.test(value)) {
          response.statusCode = 400;
          response.end('Expected a numeric value');
          return;
        }

        response.statusCode = 200;
        response.setHeader('Content-Type', 'application/json');
        response.setHeader(
          'Set-Cookie',
          `cm_smoke_network=${value}; Path=/; Max-Age=300; SameSite=Lax`
        );
        response.end(JSON.stringify({ ok: true }));
        return;
      }

      enhancedMiddleware(request, response, next);
    };
  },
};

module.exports = config;
