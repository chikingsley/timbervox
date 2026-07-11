# TimberVox iOS

Expo/React Native host app plus a native SwiftUI custom keyboard extension. The host app owns microphone capture and the Voxtral realtime WebSocket; the keyboard communicates with it through the shared App Group.

## Current prototype

- Expo SDK 57 development app with background audio recording
- Voxtral realtime streaming through `wss://timbervox.peacockery.studio/v1/realtime`
- API key stored in the iOS Keychain
- SwiftUI keyboard extension with tap typing, a visible swipe trail, local prototype swipe decoding, three predictions, and a bottom-right dictation control
- Live partial text in the keyboard and final text insertion into the current field
- Debug-only direct launch of `timbervox://session` when no session is active

The swipe decoder is intentionally a small geometric prototype, not yet a SwiftKey-quality language model. The keyboard extension itself cannot capture microphone audio on iOS.

## Run

```bash
cd apps/ios
pnpm install
pnpm check
pnpm prebuild:ios
pnpm ios
```

This requires a development build; Expo Go cannot contain the keyboard extension. After installing, enable **Settings > General > Keyboard > Keyboards > Add New Keyboard > TimberVoxKeyboard** and grant Full Access so the App Group bridge can operate.

In the TimberVox app, save an API key and start a session. The app may then stay in the background while the keyboard's microphone button starts and stops realtime dictation.

## Personal and distribution modes

The Debug keyboard tries to open the TimberVox host app when a session is not running. This is useful for an Xcode-installed personal development build, but it is deliberately compiled out of Release because App Review guideline 4.4.1 forbids a keyboard extension from launching apps other than Settings.

The release-safe flow is to start the host session first, either in the app or from a future Shortcut/App Intent, and then return to the destination app. A signed physical-device run is required to validate background survival, App Group delivery, microphone behavior, and keyboard insertion end to end.
