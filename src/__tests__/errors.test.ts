import { describe, expect, it } from '@jest/globals';
import { isCookieManagerError } from '../errors';

describe('isCookieManagerError', () => {
  it.each([
    'invalid_url',
    'invalid_cookie',
    'domain_mismatch',
    'not_supported',
    'storage_error',
    'network_error',
  ])('accepts the stable %s code', (code) => {
    expect(isCookieManagerError({ code, message: 'Diagnostic message' })).toBe(
      true
    );
  });

  it('rejects legacy, unknown, and malformed errors', () => {
    expect(
      isCookieManagerError({ code: 'cookie_set_error', message: 'Legacy' })
    ).toBe(false);
    expect(
      isCookieManagerError({ code: 'future_error', message: 'Unknown' })
    ).toBe(false);
    expect(isCookieManagerError({ code: 'invalid_url' })).toBe(false);
    expect(isCookieManagerError(new Error('No code'))).toBe(false);
    expect(isCookieManagerError(null)).toBe(false);
  });
});
