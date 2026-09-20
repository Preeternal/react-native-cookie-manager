export type CookieManagerErrorCode =
  | 'invalid_url'
  | 'invalid_cookie'
  | 'domain_mismatch'
  | 'not_supported'
  | 'storage_error'
  | 'network_error';

export type CookieManagerError = Error & {
  readonly code: CookieManagerErrorCode;
};

const COOKIE_MANAGER_ERROR_CODES: ReadonlySet<string> = new Set([
  'invalid_url',
  'invalid_cookie',
  'domain_mismatch',
  'not_supported',
  'storage_error',
  'network_error',
]);

export const isCookieManagerError = (
  error: unknown
): error is CookieManagerError =>
  typeof error === 'object' &&
  error !== null &&
  'code' in error &&
  typeof error.code === 'string' &&
  COOKIE_MANAGER_ERROR_CODES.has(error.code) &&
  'message' in error &&
  typeof error.message === 'string';

export const createCookieManagerError = (
  code: CookieManagerErrorCode,
  message: string
): CookieManagerError => Object.assign(new Error(message), { code });
