import { Platform, type EventSubscription } from 'react-native';
import CookieManagerNative, {
  type Cookie,
  type CookieChangeEvent,
  type CookieChangeStore,
  type CookieSameSite,
  type Cookies,
} from './NativeCookieManager';

export type IOSCookieStore = 'foundation' | 'webKit' | 'both';

export type RemoveSessionCookiesOptions = {
  iosCookieStore?: IOSCookieStore;
};

export type CookieChangeListener = (event: CookieChangeEvent) => void;

let cookieChangeSubscriberCount = 0;

const addCookieChangeListener = (
  listener: CookieChangeListener
): EventSubscription => {
  if (Platform.OS !== 'ios') {
    const error = new Error(
      'Cookie change subscriptions are only supported on iOS'
    ) as Error & { code: 'not_supported' };
    error.code = 'not_supported';
    throw error;
  }

  const nativeSubscription = CookieManagerNative.onCookieChange(listener);

  if (cookieChangeSubscriberCount === 0) {
    try {
      CookieManagerNative.startCookieChangeObserving();
    } catch (error) {
      nativeSubscription.remove();
      throw error;
    }
  }
  cookieChangeSubscriberCount += 1;

  let removed = false;
  return {
    remove: () => {
      if (removed) {
        return;
      }
      removed = true;
      nativeSubscription.remove();
      cookieChangeSubscriberCount -= 1;
      if (cookieChangeSubscriberCount === 0) {
        CookieManagerNative.stopCookieChangeObserving();
      }
    },
  };
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
  addCookieChangeListener,
  getAll: (useWebKit = false) => CookieManagerNative.getAll(useWebKit),
  getAllAsArray: (useWebKit = false) =>
    CookieManagerNative.getAllAsArray(useWebKit),
  clearAll: (useWebKit = false) => CookieManagerNative.clearAll(useWebKit),
  clearAllStores: () => CookieManagerNative.clearAllStores(),
  get: (url: string, useWebKit = false) =>
    CookieManagerNative.getCookies(url, useWebKit),
  getAsArray: (url: string, useWebKit = false) =>
    CookieManagerNative.getAsArray(url, useWebKit),
  getCookieHeader: (url: string, useWebKit = false) =>
    CookieManagerNative.getCookieHeader(url, useWebKit),
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

export type {
  Cookie,
  CookieChangeEvent,
  CookieChangeStore,
  CookieSameSite,
  Cookies,
};
export default CookieManager;
