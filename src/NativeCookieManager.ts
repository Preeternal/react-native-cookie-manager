import {
  TurboModuleRegistry,
  type CodegenTypes,
  type TurboModule,
} from 'react-native';

export type CookieSameSite = 'lax' | 'strict' | 'none';

export type Cookie = {
  name: string;
  value: string;
  path?: string;
  domain?: string;
  version?: string;
  expires?: string;
  secure?: boolean;
  httpOnly?: boolean;
  sameSite?: CookieSameSite;
  maxAge?: number;
};

export type Cookies = Record<string, Cookie>;

export type IOSCookieStore = 'foundation' | 'webKit';

export type CookieChangeEvent = {
  iosCookieStore: IOSCookieStore;
};

export interface Spec extends TurboModule {
  readonly onCookieChange: CodegenTypes.EventEmitter<CookieChangeEvent>;
  startCookieChangeObserving(): void;
  stopCookieChangeObserving(): void;
  setCookie(
    url: string,
    cookie: Cookie,
    useWebKit: boolean,
    validate: boolean
  ): Promise<boolean>;
  setFromResponse(url: string, cookie: string): Promise<boolean>;
  getCookies(url: string, useWebKit?: boolean): Promise<Cookies>;
  getAsArray(url: string, useWebKit?: boolean): Promise<ReadonlyArray<Cookie>>;
  getCookieHeader(url: string, useWebKit?: boolean): Promise<string>;
  /**
   * @deprecated Make the request with `fetch`/Axios and then call `get()`.
   * The native name is retained for upstream API compatibility.
   */
  getFromResponse(url: string): Promise<Cookies>;
  clearAll(useWebKit?: boolean): Promise<boolean>;
  clearAllStores(): Promise<boolean>;
  flush(): Promise<void>;
  removeSessionCookies(
    iosClearFoundation: boolean,
    iosClearWebKit: boolean
  ): Promise<boolean>;
  getAll(useWebKit?: boolean): Promise<Cookies>;
  getAllAsArray(useWebKit?: boolean): Promise<ReadonlyArray<Cookie>>;
  clearByName(url: string, name: string, useWebKit?: boolean): Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('CookieManager');
