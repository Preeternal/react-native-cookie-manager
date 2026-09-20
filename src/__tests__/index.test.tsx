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
    setCookie: jest.fn(async () => true),
    getCookies: jest.fn(async () => ({})),
    getAsArray: jest.fn(async () => []),
    getCookieHeader: jest.fn(async () => ''),
    getAll: jest.fn(async () => ({})),
    getAllAsArray: jest.fn(async () => []),
    clearAll: jest.fn(async () => true),
    clearByName: jest.fn(async () => true),
  },
}));

import mockNativeModule from '../NativeCookieManager';
import CookieManager, { isCookieManagerError } from '../index';

const mockRemoveSessionCookies = jest.mocked(
  mockNativeModule.removeSessionCookies
);
const mockSetCookie = jest.mocked(mockNativeModule.setCookie);
const mockGetCookies = jest.mocked(mockNativeModule.getCookies);
const mockGetAsArray = jest.mocked(mockNativeModule.getAsArray);
const mockGetCookieHeader = jest.mocked(mockNativeModule.getCookieHeader);
const mockGetAll = jest.mocked(mockNativeModule.getAll);
const mockGetAllAsArray = jest.mocked(mockNativeModule.getAllAsArray);
const mockClearAll = jest.mocked(mockNativeModule.clearAll);
const mockClearByName = jest.mocked(mockNativeModule.clearByName);
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
      expect(isCookieManagerError(error)).toBe(true);
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

describe('set', () => {
  const cookie = { name: 'session', value: 'value' };

  beforeEach(() => {
    mockSetCookie.mockClear();
  });

  it('uses Foundation and validation by default', async () => {
    await expect(
      CookieManager.set('https://example.com', cookie)
    ).resolves.toBe(true);

    expect(mockSetCookie).toHaveBeenCalledWith(
      'https://example.com',
      cookie,
      false,
      true
    );
  });

  it('keeps the legacy boolean selector with validation enabled', async () => {
    await CookieManager.set('https://example.com', cookie, true);

    expect(mockSetCookie).toHaveBeenCalledWith(
      'https://example.com',
      cookie,
      true,
      true
    );
  });

  it('normalizes store and the temporary validation escape hatch', async () => {
    await CookieManager.set('https://example.com', cookie, {
      iosCookieStore: 'webKit',
      validate: false,
    });

    expect(mockSetCookie).toHaveBeenCalledWith(
      'https://example.com',
      cookie,
      true,
      false
    );
  });

  it('rejects unknown fields before reaching native code by default', async () => {
    const input = { ...cookie, partitioned: true };

    await expect(
      CookieManager.set('https://example.com', input)
    ).rejects.toMatchObject({ code: 'invalid_cookie' });
    expect(mockSetCookie).not.toHaveBeenCalled();
  });

  it('lets the v6 compatibility path ignore unknown fields', async () => {
    const input = { ...cookie, legacyAttribute: 'ignored' };

    await CookieManager.set('https://example.com', input, {
      validate: false,
    });

    expect(mockSetCookie).toHaveBeenCalledWith(
      'https://example.com',
      input,
      false,
      false
    );
  });

  it('rejects invalid runtime options with a stable code', async () => {
    await expect(
      CookieManager.set('https://example.com', cookie, {
        iosCookieStore: 'invalid',
      } as never)
    ).rejects.toMatchObject({ code: 'invalid_cookie' });
    expect(mockSetCookie).not.toHaveBeenCalled();
  });

  it('does not accept the removeSessionCookies-only both selector', async () => {
    await expect(
      CookieManager.set('https://example.com', cookie, {
        iosCookieStore: 'both',
      } as never)
    ).rejects.toMatchObject({ code: 'invalid_cookie' });
    expect(mockSetCookie).not.toHaveBeenCalled();
  });
});

describe('iOS cookie store options', () => {
  beforeEach(() => {
    mockGetCookies.mockClear();
    mockGetAsArray.mockClear();
    mockGetCookieHeader.mockClear();
    mockGetAll.mockClear();
    mockGetAllAsArray.mockClear();
    mockClearAll.mockClear();
    mockClearByName.mockClear();
  });

  it('uses Foundation when options are omitted', async () => {
    await CookieManager.get('https://example.com');
    await CookieManager.getAll();
    await CookieManager.clearAll();

    expect(mockGetCookies).toHaveBeenCalledWith('https://example.com', false);
    expect(mockGetAll).toHaveBeenCalledWith(false);
    expect(mockClearAll).toHaveBeenCalledWith(false);
  });

  it('normalizes the WebKit option for every selector method', async () => {
    const options = { iosCookieStore: 'webKit' } as const;

    await CookieManager.get('https://example.com', options);
    await CookieManager.getAsArray('https://example.com', options);
    await CookieManager.getCookieHeader('https://example.com', options);
    await CookieManager.getAll(options);
    await CookieManager.getAllAsArray(options);
    await CookieManager.clearAll(options);
    await CookieManager.clearByName('https://example.com', 'session', options);

    expect(mockGetCookies).toHaveBeenCalledWith('https://example.com', true);
    expect(mockGetAsArray).toHaveBeenCalledWith('https://example.com', true);
    expect(mockGetCookieHeader).toHaveBeenCalledWith(
      'https://example.com',
      true
    );
    expect(mockGetAll).toHaveBeenCalledWith(true);
    expect(mockGetAllAsArray).toHaveBeenCalledWith(true);
    expect(mockClearAll).toHaveBeenCalledWith(true);
    expect(mockClearByName).toHaveBeenCalledWith(
      'https://example.com',
      'session',
      true
    );
  });

  it('preserves legacy boolean selectors throughout v7', async () => {
    await CookieManager.get('https://example.com', true);
    await CookieManager.getAll(true);
    await CookieManager.clearByName('https://example.com', 'session', true);

    expect(mockGetCookies).toHaveBeenCalledWith('https://example.com', true);
    expect(mockGetAll).toHaveBeenCalledWith(true);
    expect(mockClearByName).toHaveBeenCalledWith(
      'https://example.com',
      'session',
      true
    );
  });

  it('rejects invalid selectors before reaching native code', async () => {
    await expect(
      CookieManager.get('https://example.com', {
        iosCookieStore: 'both',
      } as never)
    ).rejects.toMatchObject({ code: 'invalid_cookie' });

    expect(mockGetCookies).not.toHaveBeenCalled();
  });
});
