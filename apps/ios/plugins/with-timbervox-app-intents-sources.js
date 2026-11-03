const { PBXFileSystemSynchronizedRootGroup } = require("@bacons/xcode");
const { getMainAppTarget } = require("@bacons/apple-targets/build/target");
const {
  withXcodeProjectBeta,
} = require("@bacons/apple-targets/build/with-bacons-xcode");

// The App Shortcut intent must perform in the main app process: only the app
// may declare the audio background mode, and cross-process audio sessions were
// failing to activate with AVAudioSessionErrorCodeCannotInterruptOthers. These
// sources live outside any extension target, so this plugin syncs them into
// the app target alone. (Apple rejects UIBackgroundModes in an App Intents
// extension — ITMS-91092 — and the system prefers the extension whenever both
// processes contain the intent, so keeping a separate extension is not an
// option.)
const SOURCE_GROUP_PATH = "../targets/app-intents";

module.exports = function withTimbervoxAppIntentsSources(config) {
  return withXcodeProjectBeta(config, (projectConfig) => {
    const project = projectConfig.modResults;
    const mainAppTarget = getMainAppTarget(project);

    const mainGroupChildren = project.rootObject.props.mainGroup.props.children;
    let syncGroup = mainGroupChildren.find(
      (child) =>
        child instanceof PBXFileSystemSynchronizedRootGroup &&
        child.props.path === SOURCE_GROUP_PATH,
    );
    if (!syncGroup) {
      syncGroup = PBXFileSystemSynchronizedRootGroup.create(project, {
        path: SOURCE_GROUP_PATH,
        sourceTree: "<group>",
        explicitFileTypes: {},
        explicitFolders: [],
      });
      mainGroupChildren.push(syncGroup);
    }

    if (!mainAppTarget.props.fileSystemSynchronizedGroups) {
      mainAppTarget.props.fileSystemSynchronizedGroups = [];
    }
    if (
      !mainAppTarget.props.fileSystemSynchronizedGroups.find(
        (group) => group === syncGroup,
      )
    ) {
      mainAppTarget.props.fileSystemSynchronizedGroups.push(syncGroup);
    }

    return projectConfig;
  });
};
