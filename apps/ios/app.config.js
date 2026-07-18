const path = require("node:path");

try {
  process.loadEnvFile(path.resolve(__dirname, "../..", ".env"));
} catch (error) {
  if (error?.code !== "ENOENT") throw error;
}

function developmentCredential() {
  if (process.env.PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL !== "1") return "";
  const credential = process.env.PEACOCKERY_VOICE_API_KEY?.trim();
  if (!credential) {
    throw new Error(
      "PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL=1 requires PEACOCKERY_VOICE_API_KEY",
    );
  }
  return credential;
}

module.exports = ({ config }) => {
  const credential = developmentCredential();
  return {
    ...config,
    extra: {
      ...config.extra,
      peacockeryVoiceEnvironment:
        process.env.PEACOCKERY_VOICE_ENVIRONMENT === "production"
          ? "production"
          : "lab",
      ...(credential ? { peacockeryVoiceApiKey: credential } : {}),
    },
  };
};
