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

const DEFAULT_DOMAIN = '.example.com';

const normalizeDomainInput = (value: string): string => value.trim();

const buildUrlForDomain = (domain: string): string => {
  const normalized = domain.startsWith('.') ? domain.slice(1) : domain;
  const host = domain.startsWith('.') ? `app.${normalized}` : normalized;
  return `https://${host}`;
};

export default function App() {
  const [domainInput, setDomainInput] = useState<string>(DEFAULT_DOMAIN);
  const [output, setOutput] = useState<string>('{}');
  const [status, setStatus] = useState<string>('Ready');
  const [cookieIndex, setCookieIndex] = useState<number>(1);

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
