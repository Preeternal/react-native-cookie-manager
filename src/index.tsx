import { Platform } from 'react-native';
import CookieManagerNative, {
  type Cookie,
  type Cookies,
} from './NativeCookieManager';

const CookieManager = {
  getAll: (useWebKit = false) => CookieManagerNative.getAll(useWebKit),
  clearAll: (useWebKit = false) => CookieManagerNative.clearAll(useWebKit),
  get: (url: string, useWebKit = false) =>
    CookieManagerNative.getCookies(url, useWebKit),
  set: (url: string, cookie: Cookie, useWebKit = false) =>
    CookieManagerNative.setCookie(url, cookie, useWebKit),
  clearByName: (url: string, name: string, useWebKit = false) =>
    CookieManagerNative.clearByName(url, name, useWebKit),
  flush: () =>
    Platform.OS === 'android' ? CookieManagerNative.flush() : Promise.resolve(),
  removeSessionCookies: () =>
    Platform.OS === 'android'
      ? CookieManagerNative.removeSessionCookies()
      : Promise.resolve(false),
  setFromResponse: (url: string, cookie: string) =>
    CookieManagerNative.setFromResponse(url, cookie),
  getFromResponse: (url: string) => CookieManagerNative.getFromResponse(url),
};

export type { Cookie, Cookies };
export default CookieManager;
