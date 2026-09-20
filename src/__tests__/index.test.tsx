import { beforeEach, describe, expect, it, jest } from '@jest/globals';

jest.mock('../NativeCookieManager', () => ({
  __esModule: true,
  default: {
    removeSessionCookies: jest.fn(async () => true),
  },
}));

import mockNativeModule from '../NativeCookieManager';
import CookieManager from '../index';

const mockRemoveSessionCookies = jest.mocked(
  mockNativeModule.removeSessionCookies
);

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
