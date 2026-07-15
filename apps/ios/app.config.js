const fs = require('node:fs');
const path = require('node:path');

function localTimberVoxCredential() {
  try {
    const config = fs.readFileSync(
      path.resolve(__dirname, '../../Config/keys/TimberVoxAPI.local.xcconfig'),
      'utf8',
    );
    return config.match(/^TIMBERVOX_API_KEY\s*=\s*(.+)$/m)?.[1]?.trim() ?? '';
  } catch {
    return '';
  }
}

module.exports = ({ config }) => ({
  ...config,
  extra: {
    ...config.extra,
    timberVoxApiKey: process.env.TIMBERVOX_API_KEY?.trim() || localTimberVoxCredential(),
  },
});
