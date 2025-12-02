import { TurboModuleRegistry, type TurboModule } from 'react-native';

export type Cookie = {
  name: string;
  value: string;
  path?: string;
  domain?: string;
  version?: string;
  expires?: string;
  secure?: boolean;
  httpOnly?: boolean;
};

export type Cookies = Record<string, Cookie>;

export interface Spec extends TurboModule {
  setCookie(url: string, cookie: Cookie, useWebKit?: boolean): Promise<boolean>;
  setFromResponse(url: string, cookie: string): Promise<boolean>;
  getCookies(url: string, useWebKit?: boolean): Promise<Cookies>;
  getFromResponse(url: string): Promise<Cookies>;
  clearAll(useWebKit?: boolean): Promise<boolean>;
  flush(): Promise<void>;
  removeSessionCookies(): Promise<boolean>;
  getAll(useWebKit?: boolean): Promise<Cookies>;
  clearByName(url: string, name: string, useWebKit?: boolean): Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('CookieManager');
