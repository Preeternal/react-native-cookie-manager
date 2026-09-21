import { Platform, type EventSubscription } from 'react-native';
import CookieManagerNative, {
  type Cookie,
  type CookieChangeEvent,
  type CookieChangeStore,
  type CookieSameSite,
  type Cookies,
} from './NativeCookieManager';
import {
  createCookieManagerError,
  isCookieManagerError,
  type CookieManagerError,
  type CookieManagerErrorCode,
} from './errors';

export type IOSCookieStore = 'foundation' | 'webKit';

export type IOSCookieStoreOptions = {
  iosCookieStore?: IOSCookieStore;
};

export type RemoveSessionCookiesOptions = {
  iosCookieStore?: IOSCookieStore | 'both';
};

export type SetCookieOptions = IOSCookieStoreOptions & {
  /**
   * @deprecated This temporary v7 compatibility option will be removed in the
   * next major version. Validation is enabled by default; use `false` only
   * while migrating input that relied on native-store handling in v6.
   */
  validate?: boolean;
};

export type CookieChangeListener = (event: CookieChangeEvent) => void;

let cookieChangeSubscriberCount = 0;

const addCookieChangeListener = (
  listener: CookieChangeListener
): EventSubscription => {
  if (Platform.OS !== 'ios') {
    throw createCookieManagerError(
      'not_supported',
      'Cookie change subscriptions are only supported on iOS'
    );
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
  if (
    typeof options !== 'object' ||
    options === null ||
    Array.isArray(options)
  ) {
    return Promise.reject(
      createCookieManagerError(
        'invalid_cookie',
        'Cookie store options must be an object'
      )
    );
  }

  switch (options.iosCookieStore ?? 'both') {
    case 'foundation':
      return CookieManagerNative.removeSessionCookies(true, false);
    case 'webKit':
      return CookieManagerNative.removeSessionCookies(false, true);
    case 'both':
      return CookieManagerNative.removeSessionCookies(true, true);
    default:
      return Promise.reject(
        createCookieManagerError(
          'invalid_cookie',
          'iosCookieStore must be "foundation", "webKit", or "both"'
        )
      );
  }
};

const COOKIE_FIELDS: ReadonlySet<string> = new Set([
  'name',
  'value',
  'path',
  'domain',
  'version',
  'expires',
  'secure',
  'httpOnly',
  'sameSite',
  'maxAge',
]);

type IOSCookieStoreSelection = IOSCookieStoreOptions | boolean | undefined;

const normalizeIOSCookieStore = (
  optionsOrUseWebKit: IOSCookieStoreSelection
): boolean => {
  if (typeof optionsOrUseWebKit === 'boolean') {
    return optionsOrUseWebKit;
  }

  if (optionsOrUseWebKit === undefined) {
    return false;
  }

  if (
    typeof optionsOrUseWebKit !== 'object' ||
    optionsOrUseWebKit === null ||
    Array.isArray(optionsOrUseWebKit)
  ) {
    throw createCookieManagerError(
      'invalid_cookie',
      'Cookie store options must be an object'
    );
  }

  switch (optionsOrUseWebKit.iosCookieStore) {
    case undefined:
    case 'foundation':
      return false;
    case 'webKit':
      return true;
    default:
      throw createCookieManagerError(
        'invalid_cookie',
        'iosCookieStore must be "foundation" or "webKit"'
      );
  }
};

const withIOSCookieStore = <Result,>(
  optionsOrUseWebKit: IOSCookieStoreSelection,
  operation: (useWebKit: boolean) => Promise<Result>
): Promise<Result> => {
  try {
    return operation(normalizeIOSCookieStore(optionsOrUseWebKit));
  } catch (error) {
    return Promise.reject(error);
  }
};

type IOSCookieStoreMethod<Result> = {
  (options?: IOSCookieStoreOptions): Promise<Result>;
  /** @deprecated Use `{ iosCookieStore: 'webKit' }` instead of `true`. */
  (useWebKit?: boolean): Promise<Result>;
};

type IOSCookieStoreURLMethod<Result> = {
  (url: string, options?: IOSCookieStoreOptions): Promise<Result>;
  /** @deprecated Use `{ iosCookieStore: 'webKit' }` instead of `true`. */
  (url: string, useWebKit?: boolean): Promise<Result>;
};

type ClearByName = {
  (
    url: string,
    name: string,
    options?: IOSCookieStoreOptions
  ): Promise<boolean>;
  /** @deprecated Use `{ iosCookieStore: 'webKit' }` instead of `true`. */
  (url: string, name: string, useWebKit?: boolean): Promise<boolean>;
};

type SetCookie = {
  (url: string, cookie: Cookie, options?: SetCookieOptions): Promise<boolean>;
  /**
   * @deprecated Use the options overload, for example
   * `set(url, cookie, { iosCookieStore: 'webKit' })`.
   */
  (url: string, cookie: Cookie, useWebKit?: boolean): Promise<boolean>;
};

const set: SetCookie = (
  url: string,
  cookie: Cookie,
  optionsOrUseWebKit?: SetCookieOptions | boolean
): Promise<boolean> => {
  const options =
    typeof optionsOrUseWebKit === 'object' && optionsOrUseWebKit !== null
      ? optionsOrUseWebKit
      : undefined;
  const validate = options?.validate ?? true;
  let useWebKit: boolean;

  try {
    useWebKit = normalizeIOSCookieStore(optionsOrUseWebKit);
  } catch (error) {
    return Promise.reject(error);
  }

  if (typeof validate !== 'boolean') {
    return Promise.reject(
      createCookieManagerError('invalid_cookie', 'validate must be a boolean')
    );
  }

  if (validate) {
    if (typeof cookie !== 'object' || cookie === null) {
      return Promise.reject(
        createCookieManagerError('invalid_cookie', 'cookie must be an object')
      );
    }

    const unknownField = Object.keys(cookie).find(
      (field) => !COOKIE_FIELDS.has(field)
    );
    if (unknownField !== undefined) {
      return Promise.reject(
        createCookieManagerError(
          'invalid_cookie',
          `Unknown structured cookie field: ${unknownField}`
        )
      );
    }
  }

  return CookieManagerNative.setCookie(url, cookie, useWebKit, validate);
};

const getAll: IOSCookieStoreMethod<Cookies> = (optionsOrUseWebKit) =>
  withIOSCookieStore(optionsOrUseWebKit, (useWebKit) =>
    CookieManagerNative.getAll(useWebKit)
  );

const getAllAsArray: IOSCookieStoreMethod<ReadonlyArray<Cookie>> = (
  optionsOrUseWebKit
) =>
  withIOSCookieStore(optionsOrUseWebKit, (useWebKit) =>
    CookieManagerNative.getAllAsArray(useWebKit)
  );

const clearAll: IOSCookieStoreMethod<boolean> = (optionsOrUseWebKit) =>
  withIOSCookieStore(optionsOrUseWebKit, (useWebKit) =>
    CookieManagerNative.clearAll(useWebKit)
  );

const get: IOSCookieStoreURLMethod<Cookies> = (url, optionsOrUseWebKit) =>
  withIOSCookieStore(optionsOrUseWebKit, (useWebKit) =>
    CookieManagerNative.getCookies(url, useWebKit)
  );

const getAsArray: IOSCookieStoreURLMethod<ReadonlyArray<Cookie>> = (
  url,
  optionsOrUseWebKit
) =>
  withIOSCookieStore(optionsOrUseWebKit, (useWebKit) =>
    CookieManagerNative.getAsArray(url, useWebKit)
  );

const getCookieHeader: IOSCookieStoreURLMethod<string> = (
  url,
  optionsOrUseWebKit
) =>
  withIOSCookieStore(optionsOrUseWebKit, (useWebKit) =>
    CookieManagerNative.getCookieHeader(url, useWebKit)
  );

const clearByName: ClearByName = (url, name, optionsOrUseWebKit) =>
  withIOSCookieStore(optionsOrUseWebKit, (useWebKit) =>
    CookieManagerNative.clearByName(url, name, useWebKit)
  );

const CookieManager = {
  addCookieChangeListener,
  getAll,
  getAllAsArray,
  clearAll,
  clearAllStores: () => CookieManagerNative.clearAllStores(),
  get,
  getAsArray,
  getCookieHeader,
  set,
  clearByName,
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
  CookieManagerError,
  CookieManagerErrorCode,
  CookieSameSite,
  Cookies,
};
export { isCookieManagerError };
export default CookieManager;
