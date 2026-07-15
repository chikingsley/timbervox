# Provider icons

This is the canonical source directory for TimberVox provider marks. The Expo
app compiles these SVGs into the `TimberVoxProviders` icon font with
`react-native-nano-icons`; other clients should consume the same reviewed
sources instead of maintaining copies.

- `anthropic.svg`, `cerebras.svg`, `deepseek.svg`, `elevenlabs.svg`,
  `gemini.svg`, `groq.svg`, `mistral.svg`, `nvidia.svg`, `openai.svg`, and
  `zai.svg` come from
  [`@lobehub/icons-static-svg` 1.93.0](https://github.com/lobehub/lobe-icons)
  (MIT).
- `deepgram.svg` is the Deepgram mark from
  [Simple Icons](https://simpleicons.org/?q=deepgram) (CC0-1.0).

The SVGs intentionally contain only vector paths and solid fills supported by
Nano Icons. Brand names and marks remain the property of their owners.
