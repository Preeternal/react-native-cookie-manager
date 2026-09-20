import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';
import { Platform } from 'react-native';

const mockNativeSubscriptionRemove = jest.fn();

jest.mock('../NativeCookieManager', () => ({
  __esModule: true,
  default: {
    onCookieChange: jest.fn(() => ({ remove: mockNativeSubscriptionRemove })),
    startCookieChangeObserving: jest.fn(),
    stopCookieChangeObserving: jest.fn(),
    removeSessionCookies: jest.fn(async () => true),
  },
}));

import mockNativeModule from '../NativeCookieManager';
import CookieManager from '../index';

const mockRemoveSessionCookies = jest.mocked(
  mockNativeModule.removeSessionCookies
);
const mockOnCookieChange = jest.mocked(mockNativeModule.onCookieChange);
const mockStartCookieChangeObserving = jest.mocked(
  mockNativeModule.startCookieChangeObserving
);
const mockStopCookieChangeObserving = jest.mocked(
  mockNativeModule.stopCookieChangeObserving
);

const setPlatform = (os: 'ios' | 'android') => {
  Object.defineProperty(Platform, 'OS', { configurable: true, value: os });
};

const originalPlatform = Platform.OS;

afterEach(() => {
  Object.defineProperty(Platform, 'OS', {
    configurable: true,
    value: originalPlatform,
  });
});

describe('addCookieChangeListener', () => {
  beforeEach(() => {
    setPlatform('ios');
    mockNativeSubscriptionRemove.mockClear();
    mockOnCookieChange.mockClear();
    mockStartCookieChangeObserving.mockClear();
    mockStopCookieChangeObserving.mockClear();
  });

  it('starts once for multiple subscribers and stops after the last removal', () => {
    const first = CookieManager.addCookieChangeListener(jest.fn());
    const second = CookieManager.addCookieChangeListener(jest.fn());

    expect(mockOnCookieChange).toHaveBeenCalledTimes(2);
    expect(mockStartCookieChangeObserving).toHaveBeenCalledTimes(1);

    first.remove();
    expect(mockStopCookieChangeObserving).not.toHaveBeenCalled();

    second.remove();
    expect(mockStopCookieChangeObserving).toHaveBeenCalledTimes(1);
    expect(mockNativeSubscriptionRemove).toHaveBeenCalledTimes(2);
  });

  it('supports repeated subscribe and unsubscribe cycles without duplicate starts', () => {
    const first = CookieManager.addCookieChangeListener(jest.fn());
    first.remove();
    first.remove();

    const second = CookieManager.addCookieChangeListener(jest.fn());
    second.remove();

    expect(mockStartCookieChangeObserving).toHaveBeenCalledTimes(2);
    expect(mockStopCookieChangeObserving).toHaveBeenCalledTimes(2);
    expect(mockNativeSubscriptionRemove).toHaveBeenCalledTimes(2);
  });

  it('forwards only the native store invalidation payload', () => {
    const listener = jest.fn();
    const subscription = CookieManager.addCookieChangeListener(listener);
    const nativeListener = mockOnCookieChange.mock.calls[0]?.[0];

    nativeListener?.({ store: 'webKit' });

    expect(listener).toHaveBeenCalledWith({ store: 'webKit' });
    subscription.remove();
  });

  it('throws not_supported on Android without starting native observation', () => {
    setPlatform('android');

    try {
      CookieManager.addCookieChangeListener(jest.fn());
      throw new Error('Expected addCookieChangeListener to throw');
    } catch (error) {
      expect(error).toMatchObject({ code: 'not_supported' });
    }

    expect(mockOnCookieChange).not.toHaveBeenCalled();
    expect(mockStartCookieChangeObserving).not.toHaveBeenCalled();
  });
});

describe('removeSessionCookies', () => {
  beforeEach(() => {
    mockRemoveSessionCookies.mockClear();
  });

  it('clears both iOS stores by default', async () => {
    await expect(CookieManager.removeSessionCookies()).resolves.toBe(true);
    expect(mockRemoveSessionCookies).toHaveBeenCalledWith(true, true);
  });

  it('can target each iOS store', async () => {
    await CookieManager.removeSessionCookies({ iosCookieStore: 'foundation' });
    expect(mockRemoveSessionCookies).toHaveBeenLastCalledWith(true, false);

    await CookieManager.removeSessionCookies({ iosCookieStore: 'webKit' });
    expect(mockRemoveSessionCookies).toHaveBeenLastCalledWith(false, true);
  });

  it('rejects unknown store values', async () => {
    await expect(
      CookieManager.removeSessionCookies({ iosCookieStore: 'invalid' as never })
    ).rejects.toThrow(
      'iosCookieStore must be "foundation", "webKit", or "both"'
    );
  });
});
