import { useCallback, useEffect, useState } from 'react';
import { Button, ScrollView, StyleSheet, Text, View } from 'react-native';
import CookieManager, {
  type Cookie,
} from '@preeternal/react-native-cookie-manager';

const DEMO_URL = 'https://example.com';
const demoCookie: Cookie = {
  name: 'demo',
  value: '42',
  domain: 'example.com',
  path: '/',
  secure: true,
};

export default function App() {
  const [output, setOutput] = useState<string>('{}');

  const refreshCookies = useCallback(async () => {
    try {
      const cookies = await CookieManager.get(DEMO_URL);
      console.log('Cookies for', DEMO_URL, cookies);
      setOutput(JSON.stringify(cookies, null, 2));
    } catch (error) {
      console.error('Failed to fetch cookies:', error);
      setOutput(`Error: ${error}`);
    }
  }, []);

  const setCookie = useCallback(async () => {
    try {
      await CookieManager.set(DEMO_URL, demoCookie);
      refreshCookies();
    } catch (error) {
      console.error('Failed to set cookie:', error);
    }
  }, [refreshCookies]);

  const clearCookies = useCallback(async () => {
    try {
      await CookieManager.clearAll(false);
      refreshCookies();
    } catch (error) {
      console.error('Failed to clear cookies:', error);
    }
  }, [refreshCookies]);

  useEffect(() => {
    refreshCookies();
  }, [refreshCookies]);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>@preeternal/react-native-cookie-manager</Text>
      <View style={styles.actions}>
        <Button title="Set cookie" onPress={setCookie} />
        <Button title="Clear all" onPress={clearCookies} />
        <Button title="Refresh" onPress={refreshCookies} />
      </View>
      <Text style={styles.subtitle}>Stored cookies for {DEMO_URL}:</Text>
      <View style={styles.output}>
        <Text style={styles.mono}>{output}</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'center',
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
    justifyContent: 'space-around',
    gap: 8,
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
