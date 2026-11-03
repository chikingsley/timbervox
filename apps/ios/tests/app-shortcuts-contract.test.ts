const fs = jest.requireActual("fs") as {
  existsSync(filePath: string): boolean;
  readFileSync(filePath: string, encoding: string): string;
};
const path = jest.requireActual("path") as {
  join(...parts: string[]): string;
};

const projectRoot = process.cwd();

describe("App Shortcut registration contract", () => {
  it("registers its native AppDelegate plugin in Expo config", () => {
    const appConfig = JSON.parse(
      fs.readFileSync(path.join(projectRoot, "app.json"), "utf8"),
    ) as { expo: { plugins: Array<string | unknown[]> } };
    expect(appConfig.expo.plugins).toContain(
      "./plugins/with-timbervox-app-shortcuts",
    );
  });

  it("injects exactly one host-owned provider during every prebuild", () => {
    const plugin = fs.readFileSync(
      path.join(projectRoot, "plugins", "with-timbervox-app-shortcuts.js"),
      "utf8",
    );
    const sharedIntent = fs.readFileSync(
      path.join(
        projectRoot,
        "targets",
        "app-intents",
        "AudioRecordingIntent.swift",
      ),
      "utf8",
    );

    expect(plugin).toContain('require("expo/config-plugins")');
    expect(plugin).toContain("withXcodeProject");
    expect(plugin).toContain("import AppIntents");
    expect(plugin).toContain(
      "struct TimberVoxAppShortcuts: AppShortcutsProvider",
    );
    expect(plugin).toContain("intent: AudioRecordingIntent()");
    expect(plugin).toContain(
      "configuration.buildSettings.CURRENT_PROJECT_VERSION = buildNumber",
    );
    expect(sharedIntent).not.toContain(
      "struct TimberVoxAppShortcuts: AppShortcutsProvider",
    );
  });

  it("returns the finished transcript so wrapper shortcuts can use it", () => {
    const sharedIntent = fs.readFileSync(
      path.join(
        projectRoot,
        "targets",
        "app-intents",
        "AudioRecordingIntent.swift",
      ),
      "utf8",
    );

    // Without a returned value a shortcut cannot pipe the action into Copy/If/
    // Combine steps, so every such step keeps an unfilled required field and
    // Shortcuts refuses to run the shortcut at all.
    expect(sharedIntent).toContain(
      "func perform() async throws -> some IntentResult & ReturnsValue<String>",
    );
    expect(sharedIntent).toContain("return .result(value: text)");
    expect(sharedIntent).toContain('return .result(value: "")');
    // Native delivery stays in place; the return value is additional.
    expect(sharedIntent).toContain("await copyToClipboard(text)");
  });

  it("ships a signed one-tap wrapper shortcut targeting the current bundle", () => {
    const appConfig = JSON.parse(
      fs.readFileSync(path.join(projectRoot, "app.json"), "utf8"),
    ) as { expo: { plugins: Array<string | unknown[]> } };
    expect(appConfig.expo.plugins).toContain(
      "./plugins/with-timbervox-wrapper-shortcut",
    );

    // Unsigned shortcut files cannot be imported on iOS; signed ones are
    // Apple Encrypted Archives, so the bundled artifact must start with AEA1.
    const signed = fs.readFileSync(
      path.join(
        projectRoot,
        "assets",
        "shortcuts",
        "Toggle TimberVox Dictation.shortcut",
      ),
      "latin1",
    );
    expect(signed.slice(0, 4)).toBe("AEA1");

    // The generator is the editable source of truth for the signed artifact
    // and must reference the shipping bundle identifier, not a historical one.
    const generator = fs.readFileSync(
      path.join(projectRoot, "scripts", "generate-wrapper-shortcut.py"),
      "utf8",
    );
    expect(generator).toContain('BUNDLE = "studio.peacockery.timbervox"');
    expect(generator).not.toContain("com.chiejimofor");
    expect(generator).toContain("is.workflow.actions.text.combine");
    expect(generator).toContain("is.workflow.actions.setclipboard");
    expect(generator).toContain("is.workflow.actions.notification");
    expect(generator).toContain("is.workflow.actions.vibrate");

    const nativeModule = fs.readFileSync(
      path.join(
        projectRoot,
        "modules",
        "timbervox-system",
        "ios",
        "TimberVoxSystemModule.swift",
      ),
      "utf8",
    );
    expect(nativeModule).toContain('AsyncFunction("presentShortcutImport")');
    const onboarding = fs.readFileSync(
      path.join(projectRoot, "src", "app", "(onboarding)", "shortcut.tsx"),
      "utf8",
    );
    expect(onboarding).toContain("presentShortcutImport");
  });

  it("runs capture in the background and records privacy-safe checkpoints", () => {
    const sharedIntent = fs.readFileSync(
      path.join(
        projectRoot,
        "targets",
        "app-intents",
        "AudioRecordingIntent.swift",
      ),
      "utf8",
    );

    // Back Tap and the Action Button must toggle dictation without pulling
    // TimberVox to the foreground. The privileged background microphone grant
    // rides on AudioRecordingIntent's default SystemIntent execution with
    // openAppWhenRun = false; a plain [.background] supportedModes override
    // runs it as a generic background intent and AVAudioSession activation is
    // refused with AVAudioSessionErrorCodeCannotInterruptOthers on device.
    expect(sharedIntent).not.toContain("openAppWhenRun = true");
    expect(sharedIntent).toContain("openAppWhenRun: Bool { false }");
    expect(sharedIntent).not.toContain("static var supportedModes");
    expect(sharedIntent).toContain("TimberVoxShortcutDiagnostics.record");
    expect(sharedIntent).toContain('"audio_session.set_active_failed"');
    expect(sharedIntent).toContain("audioSessionActivation(");

    // The intent performs in the main app process. An App Intents extension
    // cannot declare the audio background mode (Apple rejects the upload,
    // ITMS-91092), cross-process audio sessions failed to activate with
    // CannotInterruptOthers, and the system prefers the extension whenever
    // both processes contain the intent — so no extension target may exist.
    const extensionGone = !fs.existsSync(
      path.join(projectRoot, "targets", "shortcut"),
    );
    expect(extensionGone).toBe(true);
    const appConfig = JSON.parse(
      fs.readFileSync(path.join(projectRoot, "app.json"), "utf8"),
    ) as { expo: { extra: { eas: { build: { experimental: { ios: { appExtensions: Array<{ bundleIdentifier: string }> } } } } } } };
    const extensionIds = appConfig.expo.extra.eas.build.experimental.ios.appExtensions.map(
      (entry) => entry.bundleIdentifier,
    );
    expect(extensionIds).not.toContain("studio.peacockery.timbervox.app-intents");
  });
});
