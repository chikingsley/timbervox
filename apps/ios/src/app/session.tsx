import { Redirect } from "expo-router";

// timbervox://session is the keyboard's entry point into the app. The
// dictation session provider owns the actual session start through its
// Linking listener; this route only keeps Expo Router from rendering an
// Unmatched Route screen for the URL and lands the user on Record.
export default function SessionRoute() {
  return <Redirect href="/record" />;
}
