const {
  IOSConfig,
  withDangerousMod,
  withXcodeProject,
} = require("expo/config-plugins");
const fs = require("fs");
const path = require("path");

const SHORTCUT_BASENAME = "Toggle TimberVox Dictation.shortcut";

// Bundles the signed wrapper shortcut into the app so the native module can
// present it for one-tap import. Regenerate the file with
// scripts/generate-wrapper-shortcut.py whenever the wrapper changes.
module.exports = function withTimberVoxWrapperShortcut(config) {
  config = withDangerousMod(config, [
    "ios",
    (dangerousConfig) => {
      const source = path.join(
        dangerousConfig.modRequest.projectRoot,
        "assets",
        "shortcuts",
        SHORTCUT_BASENAME,
      );
      if (!fs.existsSync(source)) {
        throw new Error(`Missing signed wrapper shortcut at ${source}`);
      }
      const destination = path.join(
        dangerousConfig.modRequest.platformProjectRoot,
        "TimberVox",
        SHORTCUT_BASENAME,
      );
      fs.copyFileSync(source, destination);
      return dangerousConfig;
    },
  ]);

  return withXcodeProject(config, (projectConfig) => {
    const project = projectConfig.modResults;
    const filePath = `TimberVox/${SHORTCUT_BASENAME}`;
    if (!project.hasFile(filePath)) {
      IOSConfig.XcodeUtils.addResourceFileToGroup({
        filepath: filePath,
        groupName: "TimberVox",
        isBuildFile: true,
        project,
      });
    }
    return projectConfig;
  });
};
