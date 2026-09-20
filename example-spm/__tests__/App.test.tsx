/**
 * @format
 */

import { jest, test } from '@jest/globals';
import ReactTestRenderer from 'react-test-renderer';
import App from '../src/App';

jest.mock('@preeternal/react-native-cookie-manager', () => ({
  __esModule: true,
  default: {
    clearAllStores: jest.fn(async () => true),
    clearByName: jest.fn(async () => true),
    get: jest.fn(async () => ({})),
    getAll: jest.fn(async () => ({})),
    getAsArray: jest.fn(async () => []),
    getCookieHeader: jest.fn(async () => ''),
    removeSessionCookies: jest.fn(async () => true),
    set: jest.fn(async () => true),
    setFromResponse: jest.fn(async () => true),
  },
}));

test('renders correctly', async () => {
  await ReactTestRenderer.act(() => {
    ReactTestRenderer.create(<App />);
  });
});
