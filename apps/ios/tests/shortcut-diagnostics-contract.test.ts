const fs = jest.requireActual("fs") as {
  readFileSync(filePath: string, encoding: string): string;
};
const path = jest.requireActual("path") as {
  join(...parts: string[]): string;
};

const projectRoot = process.cwd();

describe("Shortcut diagnostics contract", () => {
  it("exports and clears the App Group checkpoint log through the native module", () => {
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
    const typescriptModule = fs.readFileSync(
      path.join(projectRoot, "modules", "timbervox-system", "src", "index.ts"),
      "utf8",
    );

    expect(nativeModule).toContain('Function("getShortcutDiagnostics")');
    expect(nativeModule).toContain('Function("clearShortcutDiagnostics")');
    expect(nativeModule).toContain('"ShortcutDiagnostics"');
    expect(typescriptModule).toContain("getShortcutDiagnostics");
    expect(typescriptModule).toContain("clearShortcutDiagnostics");
  });

  it("provides copy and clear actions in Settings", () => {
    const settings = fs.readFileSync(
      path.join(projectRoot, "src", "app", "(tabs)", "settings", "index.tsx"),
      "utf8",
    );

    expect(settings).toContain('testID="settings-copy-shortcut-diagnostics"');
    expect(settings).toContain('testID="settings-clear-shortcut-diagnostics"');
    expect(settings).toContain(
      "The export excludes transcripts, audio, and credentials.",
    );
  });
});
