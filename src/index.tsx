import { Platform } from 'react-native';
import CookieManagerNative, {
  type Cookie,
  type Cookies,
} from './NativeCookieManager';

export type IOSCookieStore = 'foundation' | 'webKit' | 'both';

export type RemoveSessionCookiesOptions = {
  iosCookieStore?: IOSCookieStore;
};

const removeSessionCookies = (
  options: RemoveSessionCookiesOptions = {}
): Promise<boolean> => {
  switch (options.iosCookieStore ?? 'both') {
    case 'foundation':
      return CookieManagerNative.removeSessionCookies(true, false);
    case 'webKit':
      return CookieManagerNative.removeSessionCookies(false, true);
    case 'both':
      return CookieManagerNative.removeSessionCookies(true, true);
    default:
      return Promise.reject(
        new Error('iosCookieStore must be "foundation", "webKit", or "both"')
      );
  }
};

const CookieManager = {
  getAll: (useWebKit = false) => CookieManagerNative.getAll(useWebKit),
  getAllAsArray: (useWebKit = false) =>
    CookieManagerNative.getAllAsArray(useWebKit),
  clearAll: (useWebKit = false) => CookieManagerNative.clearAll(useWebKit),
  clearAllStores: () => CookieManagerNative.clearAllStores(),
  get: (url: string, useWebKit = false) =>
    CookieManagerNative.getCookies(url, useWebKit),
  getAsArray: (url: string, useWebKit = false) =>
    CookieManagerNative.getAsArray(url, useWebKit),
  set: (url: string, cookie: Cookie, useWebKit = false) =>
    CookieManagerNative.setCookie(url, cookie, useWebKit),
  clearByName: (url: string, name: string, useWebKit = false) =>
    CookieManagerNative.clearByName(url, name, useWebKit),
  flush: () =>
    Platform.OS === 'android' ? CookieManagerNative.flush() : Promise.resolve(),
  removeSessionCookies,
  setFromResponse: (url: string, cookie: string) =>
    CookieManagerNative.setFromResponse(url, cookie),
  /**
   * @deprecated Make the request with `fetch`/Axios and then call `get()`.
   * This upstream-compatible method performs its own GET request.
   */
  getFromResponse: (url: string) => CookieManagerNative.getFromResponse(url),
};

export type { Cookie, Cookies };
export default CookieManager;
