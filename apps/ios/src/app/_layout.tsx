import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { useColorScheme } from 'react-native';

import { DictationSessionProvider } from '@/features/dictation/dictation-session';

export default function RootLayout() {
  const colorScheme = useColorScheme();
  return (
    <DictationSessionProvider>
      <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
        <Stack screenOptions={{ headerShown: false }} />
      </ThemeProvider>
    </DictationSessionProvider>
  );
}
