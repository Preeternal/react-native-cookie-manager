import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Button,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import CookieManager, {
  type Cookie,
} from '@preeternal/react-native-cookie-manager';
import {
  preparePersistenceTest,
  runDeviceSmokeTests,
  type DeviceSmokeReport,
  verifyPersistenceTest,
} from './deviceSmokeTests';

const DEFAULT_DOMAIN = '.example.com';

const normalizeDomainInput = (value: string): string => value.trim();

const buildUrlForDomain = (domain: string): string => {
  const normalized = domain.startsWith('.') ? domain.slice(1) : domain;
  const host = domain.startsWith('.') ? `app.${normalized}` : normalized;
  return `https://${host}`;
};

const reportSummary = (report: DeviceSmokeReport): string => {
  const failed = report.checks.filter(
    (check) => check.status === 'failed'
  ).length;
  const skipped = report.checks.filter(
    (check) => check.status === 'skipped'
  ).length;

  if (failed > 0) {
    return `FAILED (${failed} failed)`;
  }

  return skipped > 0 ? `PASSED (${skipped} skipped)` : 'PASSED';
};

const TestReport = ({
  report,
  testID,
}: {
  report: DeviceSmokeReport;
  testID: string;
}) => (
  <View style={styles.output}>
    <Text testID={testID} style={report.passed ? styles.passed : styles.failed}>
      {reportSummary(report)}
    </Text>
    {report.checks.map((check) => (
      <Text key={check.name} style={styles.mono}>
        {check.status === 'passed'
          ? '✓'
          : check.status === 'skipped'
            ? '○'
            : '✗'}{' '}
        {check.name}
        {check.detail ? ` — ${check.detail}` : ''}
      </Text>
    ))}
  </View>
);

export default function App() {
  const [domainInput, setDomainInput] = useState<string>(DEFAULT_DOMAIN);
  const [output, setOutput] = useState<string>('{}');
  const [status, setStatus] = useState<string>('Ready');
  const [cookieIndex, setCookieIndex] = useState<number>(1);
  const [deviceReport, setDeviceReport] = useState<DeviceSmokeReport | null>(
    null
  );
  const [deviceTestsRunning, setDeviceTestsRunning] = useState<boolean>(false);
  const [persistenceReport, setPersistenceReport] =
    useState<DeviceSmokeReport | null>(null);
  const [persistenceStatus, setPersistenceStatus] =
    useState<string>('Start with step 1');
  const [persistenceTestRunning, setPersistenceTestRunning] =
    useState<boolean>(false);

  const inspectUrl = useMemo(() => {
    const normalizedDomain = normalizeDomainInput(domainInput);
    const domain = normalizedDomain || DEFAULT_DOMAIN;
    return buildUrlForDomain(domain);
  }, [domainInput]);

  const refreshCookies = useCallback(async (urlToInspect: string) => {
    const snapshot: Record<string, unknown> = {
      inspectUrl: urlToInspect,
    };
    const errors: Record<string, string> = {};

    try {
      snapshot.sharedForUrl = await CookieManager.get(urlToInspect, false);
    } catch (error) {
      errors.sharedForUrl = String(error);
    }

    try {
      snapshot.webKitForUrl = await CookieManager.get(urlToInspect, true);
    } catch (error) {
      errors.webKitForUrl = String(error);
    }

    try {
      snapshot.allShared = await CookieManager.getAll(false);
    } catch (error) {
      errors.allShared = String(error);
    }

    try {
      snapshot.allWebKit = await CookieManager.getAll(true);
    } catch (error) {
      errors.allWebKit = String(error);
    }

    setOutput(JSON.stringify({ ...snapshot, errors }, null, 2));
  }, []);

  const addCookieForDomain = useCallback(async () => {
    const normalizedDomain = normalizeDomainInput(domainInput);
    if (!normalizedDomain) {
      setStatus('Enter a domain, e.g. .example.com');
      return;
    }

    const targetUrl = buildUrlForDomain(normalizedDomain);
    const cookieName = `manual_${cookieIndex}`;
    const cookie: Cookie = {
      name: cookieName,
      value: `value_${cookieIndex}`,
      domain: normalizedDomain,
      path: '/',
      secure: true,
    };

    setStatus(`Adding ${cookieName} for ${normalizedDomain}`);

    const results = await Promise.allSettled([
      CookieManager.set(targetUrl, cookie, false),
      CookieManager.set(targetUrl, cookie, true),
    ]);

    const rejected = results.filter((result) => result.status === 'rejected');
    if (rejected.length > 0) {
      setStatus(
        `${cookieName} added partially (${rejected.length} errors, see errors field)`
      );
    } else {
      setStatus(`${cookieName} added`);
    }

    setCookieIndex((prev) => prev + 1);
    await refreshCookies(targetUrl);
  }, [cookieIndex, domainInput, refreshCookies]);

  const clearCookies = useCallback(async () => {
    setStatus('Clearing cookies');

    await CookieManager.clearAllStores();
    setStatus('All cookies cleared');

    await refreshCookies(inspectUrl);
  }, [inspectUrl, refreshCookies]);

  const handleAddCookiePress = useCallback(() => {
    addCookieForDomain().catch((error) => {
      setStatus(`Failed to add cookie: ${String(error)}`);
    });
  }, [addCookieForDomain]);

  const handleRefreshPress = useCallback(() => {
    refreshCookies(inspectUrl).catch((error) => {
      setStatus(`Refresh failed: ${String(error)}`);
    });
  }, [inspectUrl, refreshCookies]);

  const handleDeviceTestsPress = useCallback(() => {
    setDeviceTestsRunning(true);
    setDeviceReport(null);
    setStatus('Running device smoke tests');

    runDeviceSmokeTests()
      .then((report) => {
        setDeviceReport(report);
        setStatus(
          report.passed
            ? 'Device smoke tests PASSED'
            : 'Device smoke tests FAILED'
        );
      })
      .catch((error) => {
        setStatus(`Device smoke tests failed: ${String(error)}`);
      })
      .finally(() => {
        setDeviceTestsRunning(false);
        refreshCookies(inspectUrl).catch(() => undefined);
      });
  }, [inspectUrl, refreshCookies]);

  const handlePreparePersistencePress = useCallback(() => {
    setPersistenceTestRunning(true);
    setPersistenceReport(null);
    setPersistenceStatus('Preparing cookies');

    preparePersistenceTest()
      .then((report) => {
        setPersistenceReport(report);
        setPersistenceStatus(
          report.passed
            ? 'PREPARED — force-close the app now'
            : 'Preparation FAILED — fix the failed checks and retry step 1'
        );
      })
      .catch((error) => {
        setPersistenceStatus(`Preparation failed: ${String(error)}`);
      })
      .finally(() => {
        setPersistenceTestRunning(false);
      });
  }, []);

  const handleVerifyPersistencePress = useCallback(() => {
    setPersistenceTestRunning(true);
    setPersistenceReport(null);
    setPersistenceStatus('Verifying restored cookies');

    verifyPersistenceTest()
      .then((report) => {
        setPersistenceReport(report);
        setPersistenceStatus(
          report.passed
            ? 'Persistence test PASSED; test cookies were removed'
            : 'Persistence test FAILED; see the checks below'
        );
      })
      .catch((error) => {
        setPersistenceStatus(`Verification failed: ${String(error)}`);
      })
      .finally(() => {
        setPersistenceTestRunning(false);
        refreshCookies(inspectUrl).catch(() => undefined);
      });
  }, [inspectUrl, refreshCookies]);

  useEffect(() => {
    handleRefreshPress();
  }, [handleRefreshPress]);

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>
          @preeternal/react-native-cookie-manager
        </Text>
        <Text style={styles.subtitle}>
          Cookie domain (you can include a leading dot):
        </Text>
        <TextInput
          value={domainInput}
          onChangeText={setDomainInput}
          style={styles.input}
          autoCapitalize="none"
          autoCorrect={false}
          placeholder=".example.com"
          returnKeyType="done"
          onSubmitEditing={handleAddCookiePress}
        />
        <View style={styles.actions}>
          <Button title="Add cookie" onPress={handleAddCookiePress} />
          <Button title="Clear all" onPress={clearCookies} />
          <Button title="Refresh" onPress={handleRefreshPress} />
        </View>
        <Text style={styles.subtitle}>Native device smoke tests</Text>
        <Text>
          Clears this example app&apos;s cookie stores, exercises the public
          API, then cleans up its test cookies.
        </Text>
        <Button
          title={deviceTestsRunning ? 'Running…' : 'Run device smoke tests'}
          onPress={handleDeviceTestsPress}
          disabled={deviceTestsRunning}
          testID="run-device-smoke-tests"
        />
        {deviceReport ? (
          <TestReport report={deviceReport} testID="device-smoke-result" />
        ) : null}
        <Text style={styles.subtitle}>Persistence across process restart</Text>
        <Text>
          Run this after the one-tap smoke test. Step 1 clears the example
          app&apos;s stores and creates persistent and session cookies without
          an extra manual flush.
        </Text>
        <Text>
          1. Tap Prepare and wait until PREPARED appears. Do not press Clear or
          run the smoke test afterwards.
        </Text>
        <Text>
          2. Immediately terminate the app process—not Reload or Fast Refresh.
          On Android, force-stop the app from Settings or run:
        </Text>
        <Text style={styles.mono}>
          adb shell am force-stop preeternal.reactnativecookiemanager.example
        </Text>
        <Text>
          On iOS, stop the app from Xcode or swipe it away in the Simulator app
          switcher. Then launch the app again.
        </Text>
        <Text>
          3. Tap Verify. Persistent cookies must be restored; session-cookie
          restoration is reported as platform behavior and does not decide the
          result. Verify cleans up the test cookies.
        </Text>
        <View style={styles.actions}>
          <Button
            title="1. Prepare persistence test"
            onPress={handlePreparePersistencePress}
            disabled={persistenceTestRunning}
            testID="prepare-persistence-test"
          />
          <Button
            title="3. Verify after relaunch"
            onPress={handleVerifyPersistencePress}
            disabled={persistenceTestRunning}
            testID="verify-persistence-test"
          />
        </View>
        <Text style={styles.status}>{persistenceStatus}</Text>
        {persistenceReport ? (
          <TestReport
            report={persistenceReport}
            testID="persistence-test-result"
          />
        ) : null}
        <Text style={styles.status}>{status}</Text>
        <Text style={styles.subtitle}>Current inspect URL: {inspectUrl}</Text>
        <View style={styles.output}>
          <Text style={styles.mono}>{output}</Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#fff',
  },
  container: {
    flexGrow: 1,
    justifyContent: 'flex-start',
    padding: 24,
    gap: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: '600',
  },
  subtitle: {
    fontSize: 16,
    fontWeight: '500',
  },
  actions: {
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 8,
  },
  input: {
    width: '100%',
    borderWidth: 1,
    borderColor: '#d0d0d0',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    backgroundColor: '#fff',
  },
  status: {
    width: '100%',
    color: '#333',
  },
  passed: {
    color: '#137333',
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 8,
  },
  failed: {
    color: '#b3261e',
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 8,
  },
  output: {
    width: '100%',
    borderRadius: 8,
    backgroundColor: '#f2f2f2',
    padding: 12,
  },
  mono: {
    fontFamily: 'Menlo',
  },
});
