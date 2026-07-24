import contract from "../app-group-bridge.contract.json";

declare const __dirname: string;
declare const require: (module: string) => unknown;

const { readFileSync } = require("fs") as {
  readFileSync: (path: string, encoding: string) => string;
};
const { resolve } = require("path") as {
  resolve: (...paths: string[]) => string;
};

describe("App Group bridge contract", () => {
  const typescript = readFileSync(
    resolve(__dirname, "../src/features/keyboard/app-group-bridge.ts"),
    "utf8",
  );
  const swift = readFileSync(
    resolve(__dirname, "../targets/keyboard/AppGroupBridge.swift"),
    "utf8",
  );
  const keyboardController = readFileSync(
    resolve(__dirname, "../targets/keyboard/KeyboardViewController.swift"),
    "utf8",
  );
  const keyboardSurface = readFileSync(
    resolve(__dirname, "../targets/keyboard/SwipeKeySurface.swift"),
    "utf8",
  );
  const keyboardRoot = readFileSync(
    resolve(__dirname, "../targets/keyboard/KeyboardRootView.swift"),
    "utf8",
  );
  const setupState = readFileSync(
    resolve(__dirname, "../src/features/setup/setup-state.ts"),
    "utf8",
  );
  const systemModule = readFileSync(
    resolve(
      __dirname,
      "../modules/timbervox-system/ios/TimberVoxSystemModule.swift",
    ),
    "utf8",
  );
  const welcomeScreen = readFileSync(
    resolve(__dirname, "../src/app/(onboarding)/welcome.tsx"),
    "utf8",
  );
  const session = readFileSync(
    resolve(__dirname, "../src/features/dictation/dictation-session.tsx"),
    "utf8",
  );
  const delivery = readFileSync(
    resolve(__dirname, "../src/features/dictation/result-delivery.ts"),
    "utf8",
  );
  const liveActivity = readFileSync(
    resolve(
      __dirname,
      "../targets/live-activity/TimberVoxRecordingLiveActivity.swift",
    ),
    "utf8",
  );
  const shortcutIntent = readFileSync(
    resolve(
      __dirname,
      "../targets/shortcut/_shared/AudioRecordingIntent.swift",
    ),
    "utf8",
  );
  const keys = Object.values(contract.keys).flat();

  it("keeps the schema and every public key aligned across processes", () => {
    expect(typescript).toContain(
      `const BRIDGE_SCHEMA_VERSION = ${contract.schemaVersion}`,
    );
    expect(swift).toContain(
      `static let schemaVersion = ${contract.schemaVersion}`,
    );
    expect(typescript).toContain(contract.appGroup);
    expect(swift).toContain(contract.appGroup);
    for (const key of keys) {
      expect(typescript).toContain(`"${key}"`);
      expect(swift).toContain(`case ${key}`);
    }
  });

  it("documents every code-declared bridge key in the contract", () => {
    const declaration = typescript.match(/const bridgeKeys = \[([^\]]+)\]/);
    expect(declaration).not.toBeNull();
    const codeKeys = [...declaration![1]!.matchAll(/"([^"]+)"/g)].map(
      (match) => match[1],
    );
    expect(codeKeys.length).toBeGreaterThan(0);
    const documented = new Set([...keys, "bridgeSchemaVersion"]);
    const undocumented = codeKeys.filter((key) => !documented.has(key!));
    expect(undocumented).toEqual([]);
  });

  it("publishes keyboard results with request ownership instead of v1 pending text", () => {
    expect(session).toContain('lastEntryPointRef.current === "keyboard"');
    expect(delivery).toContain('writeBridgeString("finalRequestId"');
    expect(delivery).toContain('writeBridgeString("finalResultId"');
    expect(session).not.toContain('storage.set("pendingTranscript"');
    expect(keyboardController).toContain(
      "requestID == KeyboardBridge.string(for: .keyboardRequestId)",
    );
    expect(keyboardController).toContain(
      "resultID != KeyboardBridge.string(for: .consumedResultId)",
    );
  });

  it("streams owned partials without duplicating the authoritative final result", () => {
    expect(shortcutIntent).toContain('forKey: "partialTranscriptRequestId"');
    expect(shortcutIntent).toContain('forKey: "partialTranscriptRevision"');
    expect(keyboardController).toContain(
      "requestID == KeyboardBridge.string(for: .keyboardRequestId)",
    );
    expect(keyboardController).toContain("replaceStreamedText(with: text)");
    expect(keyboardController).toContain("context.hasSuffix(verification)");
    expect(keyboardController).toContain(
      "discardStreamedText(requestID: requestID)",
    );
  });

  it("uses real metering, full-width activity signals, and distinct dictation haptics", () => {
    expect(shortcutIntent).toContain("recorder.isMeteringEnabled = true");
    expect(shortcutIntent).toContain("averagePower(forChannel: 0)");
    expect(shortcutIntent).toContain("audioLevels: activityLevels");
    expect(liveActivity).toContain(".frame(maxWidth: .infinity)");
    expect(liveActivity).toContain("TimberlineWaveform");
    expect(keyboardController).toContain("dictationFeedback(.start)");
    expect(keyboardController).toContain("dictationFeedback(.stop)");
    expect(keyboardController).toContain("notificationOccurred(.success)");
  });

  it("opens the app instead of faking a recording state without a live session", () => {
    expect(keyboardController).toContain("hasDictationKey = true");
    expect(keyboardController).toContain("extensionContext.open(url)");
    expect(keyboardController).not.toContain(
      'NSSelectorFromString("openURL:")',
    );
    expect(keyboardController).toContain(
      'KeyboardBridge.set("keyboard", for: .requestedEntryPoint)',
    );

    // The app only honours recordingRequested while a session is already live, so
    // the offline branch must open TimberVox without arming a request the app
    // will drop and without moving the key into its recording state.
    const offlineBranch = keyboardController.slice(
      keyboardController.indexOf("guard sessionActive else {"),
      keyboardController.indexOf('let requestID = "keyboard_'),
    );
    expect(offlineBranch).toContain("openPersonalSession()");
    expect(offlineBranch).not.toContain("recordingRequested = true");
    expect(offlineBranch).not.toContain(
      "KeyboardBridge.set(true, for: .recordingRequested)",
    );
    expect(session).not.toContain("const pendingKeyboardRequestId =");
  });

  it("keeps dictation state on its own key instead of the typing suggestions", () => {
    expect(keyboardController).toContain("var dictationKeyState: DictationKeyState");
    expect(keyboardRoot).toContain("DictationKey(state: model.dictationKeyState");
    // Dictation status text must never be written into the swipe/typing predictions.
    expect(keyboardController).not.toMatch(/predictions = \[\s*"/);
    expect(keyboardController).not.toMatch(/model\.predictions = \[\s*"/);
  });

  it("lets auto-capitalization be turned off", () => {
    expect(swift).toContain("case keyboardAutoCapitalizationEnabled");
    expect(swift).toContain("seed(true, for: .keyboardAutoCapitalizationEnabled)");
    expect(keyboardController).toContain("guard autoCapitalizationEnabled else {");
    expect(typescript).toContain(
      'seedBoolean("keyboardAutoCapitalizationEnabled", true)',
    );
  });

  it("draws adaptive key labels in light and dark host apps", () => {
    expect(keyboardSurface).toContain(
      ".foregroundStyle(Color(uiColor: .label))",
    );
  });

  it("uses a conventional keyboard layout with third-row delete and alternate pages", () => {
    expect(keyboardSurface).toContain("deleteFrame");
    expect(keyboardSurface).toContain('systemName: "delete.left"');
    expect(keyboardSurface).toContain("struct AlternateKeySurface");
    expect(keyboardRoot).toContain(
      'Text(model.page == .letters ? "123" : "ABC")',
    );
    expect(keyboardRoot).toContain(".frame(width: 43, height: 44)");
    expect(keyboardRoot).not.toContain('keyButton(systemName: "delete.left"');
  });

  it("keeps the recording-state decoration from swallowing the stop command", () => {
    expect(keyboardRoot).toContain(".allowsHitTesting(false)");
  });

  it("allows a pending keyboard request to be stopped before the app session opens", () => {
    const stopBranch = keyboardController.indexOf("if recordingRequested {");
    const sessionBranch = keyboardController.indexOf(
      "guard sessionActive else {",
    );

    expect(stopBranch).toBeGreaterThan(-1);
    expect(sessionBranch).toBeGreaterThan(stopBranch);
    expect(keyboardController.slice(stopBranch, sessionBranch)).toContain(
      "KeyboardBridge.set(false, for: .recordingRequested)",
    );
  });

  it("requires a fresh keyboard observation after Settings without erasing the last result", () => {
    expect(setupState).toContain("markKeyboardVerificationRequired()");
    expect(setupState).toContain("keyboardVerificationPending: true");
    expect(setupState).not.toContain(
      'writeBridgeBoolean("keyboardSeen", false)',
    );
    expect(welcomeScreen).toContain("automaticallyAdjustKeyboardInsets");
    expect(welcomeScreen).toContain("ref={verificationInput}");
    expect(welcomeScreen).toContain('pending ? "Verify below"');
  });

  it("reports restricted and full keyboard states through the containing app", () => {
    expect(keyboardController).toContain("KeyboardStatusNotifier.post");
    expect(swift).toContain("enum KeyboardStatusNotifier");
    expect(setupState).toContain("startKeyboardStatusObserver()");
    expect(setupState).toContain("getKeyboardStatus()");
    expect(systemModule).toContain('Function("getKeyboardStatus")');
    expect(systemModule).toContain(
      'Function("markKeyboardVerificationRequired")',
    );
  });
});
