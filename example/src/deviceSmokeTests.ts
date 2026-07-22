import { Platform, TurboModuleRegistry, type TurboModule } from 'react-native';
import CookieManager, {
  type Cookie,
} from '@preeternal/react-native-cookie-manager';

const TEST_URL = 'https://app.example.com/account/profile';
const TEST_DOMAIN = '.example.com';
const COOKIE_PREFIX = 'cm_smoke_';
const SESSION_COOKIE = `${COOKIE_PREFIX}session`;
const PERSISTENT_COOKIE = `${COOKIE_PREFIX}persistent`;
const EXPIRED_COOKIE = `${COOKIE_PREFIX}expired`;
const DUPLICATE_COOKIE = `${COOKIE_PREFIX}duplicate`;
const RAW_COOKIE = `${COOKIE_PREFIX}raw`;
const NETWORK_COOKIE = `${COOKIE_PREFIX}network`;
const METRO_TEST_PATH = '/__cookie_manager_smoke__';
const PERSISTENCE_URL = 'https://persistence.example.com/';
const PERSISTENCE_PREFIX = 'cm_persistence_';
const PERSISTENCE_MAX_AGE_COOKIE = `${PERSISTENCE_PREFIX}max_age`;
const PERSISTENCE_EXPIRES_COOKIE = `${PERSISTENCE_PREFIX}expires`;
const PERSISTENCE_SESSION_COOKIE = `${PERSISTENCE_PREFIX}session`;
const PERSISTENCE_VALUE = 'prepared_v1';

let persistencePreparedInCurrentProcess = false;

type CheckStatus = 'passed' | 'failed' | 'skipped';

export type DeviceSmokeCheck = {
  name: string;
  status: CheckStatus;
  detail?: string;
};

export type DeviceSmokeReport = {
  passed: boolean;
  checks: ReadonlyArray<DeviceSmokeCheck>;
};

type CookieStore = {
  label: string;
  useWebKit: boolean;
};

type SourceCodeModule = TurboModule & {
  getConstants(): { scriptURL?: string };
};

class SkippedCheck extends Error {}

const stores: ReadonlyArray<CookieStore> =
  Platform.OS === 'ios'
    ? [
        { label: 'Foundation', useWebKit: false },
        { label: 'WebKit', useWebKit: true },
      ]
    : [{ label: 'Android shared store', useWebKit: false }];

const assert: (condition: unknown, message: string) => asserts condition = (
  condition,
  message
) => {
  if (!condition) {
    throw new Error(message);
  }
};

const errorCode = (error: unknown): string | undefined => {
  if (typeof error !== 'object' || error === null || !('code' in error)) {
    return undefined;
  }

  return String(error.code);
};

const cookieCountInHeader = (header: string, name: string): number =>
  header
    .split(';')
    .map((part) => part.trim())
    .filter((part) => part.startsWith(`${name}=`)).length;

const describeCookies = (cookies: ReadonlyArray<Cookie>): string => {
  if (cookies.length === 0) {
    return 'No cookies returned';
  }

  return cookies
    .map((cookie) => {
      const attributes = [
        `domain=${cookie.domain ?? 'unavailable'}`,
        `path=${cookie.path ?? 'unavailable'}`,
        `expires=${cookie.expires ?? 'session'}`,
        `secure=${cookie.secure ?? 'unavailable'}`,
        `httpOnly=${cookie.httpOnly ?? 'unavailable'}`,
        `sameSite=${cookie.sameSite ?? 'unavailable'}`,
      ];
      return `${cookie.name}{${attributes.join(', ')}}`;
    })
    .join('; ');
};

const assertFutureExpiryWhenAvailable = (
  cookie: Cookie,
  label: string
): void => {
  if (cookie.domain === undefined) {
    return;
  }

  assert(
    typeof cookie.expires === 'string' &&
      Date.parse(cookie.expires) > Date.now(),
    `${label} is missing a future expiry; ${describeCookies([cookie])}`
  );
};

const metroOrigin = (): string => {
  const constants = TurboModuleRegistry.get<SourceCodeModule>(
    'SourceCode'
  )?.getConstants() as { scriptURL?: string } | undefined;
  const scriptURL = constants?.scriptURL;

  if (typeof scriptURL !== 'string') {
    throw new SkippedCheck('Metro URL is unavailable in this build');
  }

  const match = scriptURL.match(/^https?:\/\/[^/]+/i);
  if (!match) {
    throw new SkippedCheck('Run a debug build connected to Metro');
  }

  return match[0];
};

const recordCheck = async (
  checks: DeviceSmokeCheck[],
  name: string,
  check: () => Promise<string | void>
): Promise<void> => {
  try {
    const detail = await check();
    checks.push({ name, status: 'passed', detail: detail || undefined });
  } catch (error) {
    checks.push({
      name,
      status: error instanceof SkippedCheck ? 'skipped' : 'failed',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
};

const buildReport = (
  checks: ReadonlyArray<DeviceSmokeCheck>
): DeviceSmokeReport => ({
  passed: checks.every((check) => check.status !== 'failed'),
  checks,
});

export const runDeviceSmokeTests = async (): Promise<DeviceSmokeReport> => {
  const checks: DeviceSmokeCheck[] = [];
  const nonce = String(Date.now());
  let networkRequestURL: string | undefined;

  const run = async (
    name: string,
    check: () => Promise<string | void>
  ): Promise<void> => recordCheck(checks, name, check);

  await run('Clean start', async () => {
    await CookieManager.clearAllStores();
  });

  for (const store of stores) {
    await run(`${store.label}: set cookies`, async () => {
      const cookieDefaults: Pick<Cookie, 'domain' | 'secure'> = {
        domain: TEST_DOMAIN,
        secure: true,
      };

      const results = await Promise.all([
        CookieManager.set(
          TEST_URL,
          {
            ...cookieDefaults,
            name: SESSION_COOKIE,
            value: `${nonce}_${store.useWebKit ? 'webkit' : 'shared'}`,
            path: '/',
          },
          store.useWebKit
        ),
        CookieManager.set(
          TEST_URL,
          {
            ...cookieDefaults,
            name: PERSISTENT_COOKIE,
            value: nonce,
            path: '/',
            httpOnly: true,
            sameSite: 'lax',
            maxAge: 600,
          },
          store.useWebKit
        ),
        CookieManager.set(
          TEST_URL,
          {
            ...cookieDefaults,
            name: DUPLICATE_COOKIE,
            value: 'root',
            path: '/',
          },
          store.useWebKit
        ),
        CookieManager.set(
          TEST_URL,
          {
            ...cookieDefaults,
            name: DUPLICATE_COOKIE,
            value: 'account',
            path: '/account',
          },
          store.useWebKit
        ),
      ]);

      assert(results.every(Boolean), 'At least one set() returned false');
    });

    await run(`${store.label}: duplicate-preserving read`, async () => {
      const cookies = await CookieManager.getAsArray(TEST_URL, store.useWebKit);
      const duplicates = cookies.filter(
        (cookie) => cookie.name === DUPLICATE_COOKIE
      );

      assert(
        duplicates.length === 2,
        `Expected 2 variants, got ${duplicates.length}`
      );
      assert(
        duplicates.some((cookie) => cookie.path === '/'),
        'Missing root-path variant'
      );
      assert(
        duplicates.some((cookie) => cookie.path === '/account'),
        'Missing /account variant'
      );
    });

    await run(`${store.label}: structured metadata`, async () => {
      const cookies = await CookieManager.getAsArray(TEST_URL, store.useWebKit);
      const cookie = cookies.find((item) => item.name === PERSISTENT_COOKIE);

      assert(cookie, 'Persistent cookie was not returned');
      if (Platform.OS === 'android' && cookie.domain === undefined) {
        throw new SkippedCheck(
          'Android System WebView uses the name/value-only fallback'
        );
      }

      assert(
        cookie.domain?.toLowerCase() === TEST_DOMAIN,
        'Domain was not preserved'
      );
      assert(cookie.path === '/', 'Path was not preserved');
      assert(cookie.secure === true, 'Secure was not preserved');
      assert(cookie.httpOnly === true, 'HttpOnly was not preserved');
      assert(cookie.sameSite === 'lax', 'SameSite was not preserved');
      assert(
        typeof cookie.expires === 'string' &&
          Date.parse(cookie.expires) > Date.now(),
        'Max-Age did not produce a future expiry'
      );
    });

    await run(`${store.label}: absolute expiry`, async () => {
      await CookieManager.set(
        TEST_URL,
        {
          name: EXPIRED_COOKIE,
          value: nonce,
          domain: TEST_DOMAIN,
          path: '/',
          secure: true,
          expires: new Date(Date.now() - 60_000).toISOString(),
        },
        store.useWebKit
      );

      const cookies = await CookieManager.getAsArray(TEST_URL, store.useWebKit);
      assert(
        cookies.every((cookie) => cookie.name !== EXPIRED_COOKIE),
        'A cookie with a past Expires date remained in the store'
      );
    });

    await run(`${store.label}: request header`, async () => {
      const header = await CookieManager.getCookieHeader(
        TEST_URL,
        store.useWebKit
      );

      assert(
        header.includes(`${SESSION_COOKIE}=`),
        'Session cookie is missing from the header'
      );
      assert(
        cookieCountInHeader(header, DUPLICATE_COOKIE) === 2,
        'Header did not preserve both same-name variants'
      );
    });
  }

  await run('setFromResponse()', async () => {
    const stored = await CookieManager.setFromResponse(
      TEST_URL,
      `${RAW_COOKIE}=${nonce}; Domain=${TEST_DOMAIN}; Path=/; Max-Age=600; Secure; HttpOnly; SameSite=Lax`
    );
    assert(stored, 'setFromResponse() returned false');

    const cookies = await CookieManager.getAsArray(TEST_URL, false);
    assert(
      cookies.some(
        (cookie) => cookie.name === RAW_COOKIE && cookie.value === nonce
      ),
      'Imported cookie was not returned'
    );
  });

  await run('Fetch response → native store', async () => {
    networkRequestURL = `${metroOrigin()}${METRO_TEST_PATH}?value=${encodeURIComponent(nonce)}`;
    const response = await fetch(networkRequestURL);
    const body = await response.text();

    assert(response.ok, `Metro endpoint returned ${response.status}: ${body}`);

    const cookies = await CookieManager.get(networkRequestURL, false);
    assert(
      cookies[NETWORK_COOKIE]?.value === nonce,
      'Cookie was not visible immediately after the response completed'
    );
  });

  for (const store of stores) {
    await run(`${store.label}: clearByName()`, async () => {
      try {
        const removed = await CookieManager.clearByName(
          TEST_URL,
          DUPLICATE_COOKIE,
          store.useWebKit
        );
        assert(removed, 'clearByName() returned false');
      } catch (error) {
        if (Platform.OS === 'android' && errorCode(error) === 'not_supported') {
          throw new SkippedCheck(
            'Android System WebView does not support GET_COOKIE_INFO'
          );
        }
        throw error;
      }

      const cookies = await CookieManager.getAsArray(TEST_URL, store.useWebKit);
      assert(
        cookies.every((cookie) => cookie.name !== DUPLICATE_COOKIE),
        'A same-name variant remained after cleanup'
      );
    });
  }

  await run('removeSessionCookies()', async () => {
    const removed = await CookieManager.removeSessionCookies();
    assert(removed, 'removeSessionCookies() returned false');

    for (const store of stores) {
      const cookies = await CookieManager.getAsArray(TEST_URL, store.useWebKit);
      assert(
        cookies.every((cookie) => cookie.name !== SESSION_COOKIE),
        `${store.label}: session cookie remained`
      );
      assert(
        cookies.some((cookie) => cookie.name === PERSISTENT_COOKIE),
        `${store.label}: persistent cookie was removed`
      );
    }
  });

  await run('Final cleanup', async () => {
    await CookieManager.clearAllStores();

    for (const store of stores) {
      const cookies = await CookieManager.getAsArray(TEST_URL, store.useWebKit);
      assert(
        cookies.every((cookie) => !cookie.name.startsWith(COOKIE_PREFIX)),
        `${store.label}: smoke-test cookies remained`
      );
    }

    if (networkRequestURL) {
      const cookies = await CookieManager.get(networkRequestURL, false);
      assert(
        cookies[NETWORK_COOKIE] === undefined,
        'Network response cookie remained'
      );
    }
  });

  return buildReport(checks);
};

export const preparePersistenceTest = async (): Promise<DeviceSmokeReport> => {
  const checks: DeviceSmokeCheck[] = [];
  const expires = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  persistencePreparedInCurrentProcess = false;

  await recordCheck(checks, 'Clear previous test state', async () => {
    await CookieManager.clearAllStores();
  });

  for (const store of stores) {
    await recordCheck(checks, `${store.label}: prepare cookies`, async () => {
      const results = await Promise.all([
        CookieManager.set(
          PERSISTENCE_URL,
          {
            name: PERSISTENCE_MAX_AGE_COOKIE,
            value: PERSISTENCE_VALUE,
            domain: 'persistence.example.com',
            path: '/',
            secure: true,
            httpOnly: true,
            sameSite: 'lax',
            maxAge: 24 * 60 * 60,
          },
          store.useWebKit
        ),
        CookieManager.set(
          PERSISTENCE_URL,
          {
            name: PERSISTENCE_EXPIRES_COOKIE,
            value: PERSISTENCE_VALUE,
            domain: 'persistence.example.com',
            path: '/',
            secure: true,
            httpOnly: true,
            sameSite: 'lax',
            expires,
          },
          store.useWebKit
        ),
        CookieManager.set(
          PERSISTENCE_URL,
          {
            name: PERSISTENCE_SESSION_COOKIE,
            value: PERSISTENCE_VALUE,
            domain: 'persistence.example.com',
            path: '/',
            secure: true,
          },
          store.useWebKit
        ),
      ]);

      assert(results.every(Boolean), 'At least one set() returned false');

      const cookies = await CookieManager.getAsArray(
        PERSISTENCE_URL,
        store.useWebKit
      );
      assert(
        cookies.some(
          (cookie) =>
            cookie.name === PERSISTENCE_MAX_AGE_COOKIE &&
            cookie.value === PERSISTENCE_VALUE
        ),
        'Max-Age cookie was not visible before restart'
      );
      assert(
        cookies.some(
          (cookie) =>
            cookie.name === PERSISTENCE_EXPIRES_COOKIE &&
            cookie.value === PERSISTENCE_VALUE
        ),
        'Expires cookie was not visible before restart'
      );
      assert(
        cookies.some(
          (cookie) =>
            cookie.name === PERSISTENCE_SESSION_COOKIE &&
            cookie.value === PERSISTENCE_VALUE
        ),
        'Session cookie was not visible before restart'
      );

      const maxAgeCookie = cookies.find(
        (cookie) => cookie.name === PERSISTENCE_MAX_AGE_COOKIE
      );
      const expiresCookie = cookies.find(
        (cookie) => cookie.name === PERSISTENCE_EXPIRES_COOKIE
      );
      assert(maxAgeCookie, 'Max-Age cookie metadata was not returned');
      assert(expiresCookie, 'Expires cookie metadata was not returned');
      assertFutureExpiryWhenAvailable(maxAgeCookie, 'Max-Age cookie');
      assertFutureExpiryWhenAvailable(expiresCookie, 'Expires cookie');

      return describeCookies(cookies);
    });
  }

  const report = buildReport(checks);
  persistencePreparedInCurrentProcess = report.passed;
  return report;
};

export const verifyPersistenceTest = async (): Promise<DeviceSmokeReport> => {
  if (persistencePreparedInCurrentProcess) {
    return {
      passed: false,
      checks: [
        {
          name: 'Process restart',
          status: 'failed',
          detail: 'Force-close and relaunch the app before Verify',
        },
      ],
    };
  }

  const checks: DeviceSmokeCheck[] = [];

  for (const store of stores) {
    let restoredCookies: ReadonlyArray<Cookie> = [];

    await recordCheck(checks, `${store.label}: restored snapshot`, async () => {
      restoredCookies = await CookieManager.getAsArray(
        PERSISTENCE_URL,
        store.useWebKit
      );
      return describeCookies(restoredCookies);
    });

    await recordCheck(
      checks,
      `${store.label}: Max-Age cookie restored`,
      async () => {
        const cookie = restoredCookies.find(
          (item) =>
            item.name === PERSISTENCE_MAX_AGE_COOKIE &&
            item.value === PERSISTENCE_VALUE
        );
        if (Platform.OS === 'ios' && store.useWebKit && !cookie) {
          throw new SkippedCheck(
            'No WKWebView was initialized before termination; WebKit durability is unavailable in this example'
          );
        }
        assert(
          cookie,
          `Max-Age cookie was not restored; ${describeCookies(restoredCookies)}`
        );
        assertFutureExpiryWhenAvailable(cookie, 'Restored Max-Age cookie');
      }
    );

    await recordCheck(
      checks,
      `${store.label}: Expires cookie restored`,
      async () => {
        const cookie = restoredCookies.find(
          (item) =>
            item.name === PERSISTENCE_EXPIRES_COOKIE &&
            item.value === PERSISTENCE_VALUE
        );
        if (Platform.OS === 'ios' && store.useWebKit && !cookie) {
          throw new SkippedCheck(
            'No WKWebView was initialized before termination; WebKit durability is unavailable in this example'
          );
        }
        assert(
          cookie,
          `Expires cookie was not restored; ${describeCookies(restoredCookies)}`
        );
        assertFutureExpiryWhenAvailable(cookie, 'Restored Expires cookie');
      }
    );

    await recordCheck(
      checks,
      `${store.label}: session policy observed`,
      async () => {
        const restored = restoredCookies.some(
          (cookie) =>
            cookie.name === PERSISTENCE_SESSION_COOKIE &&
            cookie.value === PERSISTENCE_VALUE
        );

        return restored
          ? 'Session cookie was restored by the platform'
          : 'Session cookie was not restored by the platform';
      }
    );
  }

  if (checks.every((check) => check.status !== 'failed')) {
    await recordCheck(checks, 'Persistence test cleanup', async () => {
      await CookieManager.clearAllStores();

      for (const store of stores) {
        const cookies = await CookieManager.getAsArray(
          PERSISTENCE_URL,
          store.useWebKit
        );
        assert(
          cookies.every(
            (cookie) => !cookie.name.startsWith(PERSISTENCE_PREFIX)
          ),
          `${store.label}: persistence-test cookies remained`
        );
      }
    });
  } else {
    checks.push({
      name: 'Persistence test cleanup',
      status: 'skipped',
      detail: 'Skipped after failure so the restored stores remain inspectable',
    });
  }

  return buildReport(checks);
};
