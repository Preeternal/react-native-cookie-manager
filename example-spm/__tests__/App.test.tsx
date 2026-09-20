/**
 * @format
 */

import { expect, jest, test } from '@jest/globals';
import ReactTestRenderer from 'react-test-renderer';
import CookieManager from '@preeternal/react-native-cookie-manager';
import App from '../src/App';

jest.mock('@preeternal/react-native-cookie-manager', () => ({
  __esModule: true,
  isCookieManagerError: jest.fn(() => false),
  default: {
    addCookieChangeListener: jest.fn(() => ({ remove: jest.fn() })),
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
  let renderer!: ReturnType<typeof ReactTestRenderer.create>;
  const addCookieChangeListener = jest.mocked(
    CookieManager.addCookieChangeListener
  );

  await ReactTestRenderer.act(() => {
    renderer = ReactTestRenderer.create(<App />);
  });

  expect(addCookieChangeListener).toHaveBeenCalledTimes(1);
  const subscription = addCookieChangeListener.mock.results[0]?.value as
    { remove: () => void } | undefined;

  await ReactTestRenderer.act(() => {
    renderer.unmount();
  });

  expect(subscription?.remove).toHaveBeenCalledTimes(1);
});
