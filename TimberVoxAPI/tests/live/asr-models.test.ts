import { describe, expect, it } from "vitest";

import { transcribeRemoteMedia } from "../../src/ai/transcription/service";
import { liveEnv, liveTestsEnabled } from "./env";

interface AsrCase {
  envKey: string;
  model: string;
}

const mediaUrl = new URL(
  process.env.TIMBERVOX_LIVE_ASR_MEDIA_URL ??
    "https://res.cloudinary.com/deepgram/video/upload/v1680127025/dg-audio/nasa-spacewalk-interview_ljjahn.wav"
);

const media = {
  contentType: "audio/wav",
  filename: "live-asr.wav",
  sizeBytes: 2_287_520,
  url: mediaUrl,
};

const cases: AsrCase[] = [
  { envKey: "MISTRAL_API_KEY", model: "mistral-voxtral-mini-latest" },
  { envKey: "DEEPGRAM_API_KEY", model: "deepgram-nova-3" },
  { envKey: "ELEVENLABS_API_KEY", model: "elevenlabs-scribe_v2" },
];

describe("live remote-media ASR providers", () => {
  for (const testCase of cases) {
    it(`transcribes a URL with ${testCase.model}`, async ({ skip }) => {
      if (!(liveTestsEnabled && process.env[testCase.envKey])) {
        skip("live tests disabled or provider credential unavailable");
      }
      const result = await transcribeRemoteMedia(liveEnv(), testCase.model, {
        media,
      });

      expect(result.result.text.trim().length).toBeGreaterThan(0);
      expect(
        result.result.words.length + result.result.segments.length
      ).toBeGreaterThan(0);
    });
  }

  it("preserves Deepgram URL diarization and speaker timing", async ({
    skip,
  }) => {
    if (!(liveTestsEnabled && process.env.DEEPGRAM_API_KEY)) {
      skip("live tests disabled or Deepgram credential unavailable");
    }
    const result = await transcribeRemoteMedia(liveEnv(), "deepgram-nova-3", {
      diarize: true,
      media,
      providerOptions: { deepgram: { smartFormat: true } },
    });

    expect(result.result.words.length).toBeGreaterThan(0);
    expect(result.result.speakerTurns.length).toBeGreaterThan(0);
    expect(result.result.speakerTurns[0]?.speaker).toBeDefined();
  });

  it("preserves Mistral URL diarization and segment timing", async ({
    skip,
  }) => {
    if (!(liveTestsEnabled && process.env.MISTRAL_API_KEY)) {
      skip("live tests disabled or Mistral credential unavailable");
    }
    const result = await transcribeRemoteMedia(
      liveEnv(),
      "mistral-voxtral-mini-latest",
      {
        diarize: true,
        media,
      }
    );

    expect(result.result.segments.length).toBeGreaterThan(0);
    expect(result.result.speakerTurns.length).toBeGreaterThan(0);
    expect(result.result.speakerTurns[0]?.speaker).toBeDefined();
  });
});
