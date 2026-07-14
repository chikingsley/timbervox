import { describe, expect, it } from "vitest";

import { parseDeepgramRealtimeEvent } from "../../src/ai/deepgram/realtime/events";
import { parseMistralRealtimeEvent } from "../../src/ai/mistral/realtime/events";
import {
  normalizeDeepgramTranscriptEvent,
  normalizeMistralTranscriptEvent,
  realtimeTranscriptEventFromStreamPart,
} from "../../src/ai/realtime/normalize";
import {
  terminalSessionEvent,
  transcriptProtocolEvent,
} from "../../src/ai/realtime/protocol";

const requiredTranscriptKeys = [
  "protocol_version",
  "segments",
  "sequence",
  "session_id",
  "speaker_turns",
  "text",
  "type",
  "words",
];

const required = <T>(value: T | null | undefined): T => {
  if (value === null || value === undefined) {
    throw new Error("expected contract fixture to parse");
  }
  return value;
};

describe("provider-neutral realtime protocol", () => {
  it("maps Deepgram and Mistral committed speech to the same wire shape", () => {
    const deepgram = parseDeepgramRealtimeEvent(
      JSON.stringify({
        channel: {
          alternatives: [
            {
              transcript: "Safety meeting complete.",
              words: [
                {
                  confidence: 0.99,
                  end: 1.2,
                  punctuated_word: "Safety",
                  speaker: 0,
                  start: 0.8,
                },
              ],
            },
          ],
        },
        duration: 0.4,
        is_final: true,
        speech_final: true,
        start: 0.8,
        type: "Results",
      })
    );
    const mistral = parseMistralRealtimeEvent(
      JSON.stringify({
        end: 1.2,
        speaker_id: "0",
        start: 0.8,
        text: "Safety meeting complete.",
        type: "transcription.segment",
      })
    );

    const deepgramTranscript = required(
      normalizeDeepgramTranscriptEvent(required(deepgram))
    );
    const mistralTranscript = required(
      normalizeMistralTranscriptEvent(required(mistral))
    );
    const deepgramEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      deepgramTranscript
    );
    const mistralEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      mistralTranscript
    );

    expect(required(deepgramEvent).type).toBe("transcript.committed");
    expect(required(mistralEvent).type).toBe("transcript.committed");
    expect(Object.keys(required(deepgramEvent)).sort()).toEqual(
      [...requiredTranscriptKeys, "speech_final"].sort()
    );
    expect(Object.keys(required(mistralEvent)).sort()).toEqual(
      requiredTranscriptKeys.sort()
    );
    expect(deepgramEvent).not.toHaveProperty("channel");
    expect(mistralEvent).not.toHaveProperty("speaker_id");
  });

  it("expresses provider streaming differences without provider-specific events", () => {
    const deepgram = parseDeepgramRealtimeEvent(
      JSON.stringify({
        channel: { alternatives: [{ transcript: "Safety meet" }] },
        is_final: false,
        type: "Results",
      })
    );
    const mistral = parseMistralRealtimeEvent(
      JSON.stringify({
        text: "Safety meet",
        type: "transcription.text.delta",
      })
    );
    const deepgramEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      required(normalizeDeepgramTranscriptEvent(required(deepgram)))
    );
    const mistralEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      required(normalizeMistralTranscriptEvent(required(mistral)))
    );

    expect(required(deepgramEvent).type).toBe("transcript.interim");
    expect(required(mistralEvent).type).toBe("transcript.delta");
    expect(Object.keys(required(deepgramEvent)).sort()).toEqual(
      requiredTranscriptKeys.sort()
    );
    expect(Object.keys(required(mistralEvent)).sort()).toEqual(
      requiredTranscriptKeys.sort()
    );
  });

  it("uses one terminal result contract for either provider", () => {
    const base = {
      audioBytes: 32_000,
      endedAt: "2026-07-11T12:00:01.000Z",
      language: "en",
      messageCount: 10,
      model: "test-model",
      sampleRate: 16_000,
      sessionId: "rt_contract",
      startedAt: "2026-07-11T12:00:00.000Z",
      status: "succeeded" as const,
      transcript: "Safety meeting complete.",
    };
    const deepgram = terminalSessionEvent({ ...base, provider: "deepgram" }, 4);
    const mistral = terminalSessionEvent({ ...base, provider: "mistral" }, 4);

    expect(deepgram.type).toBe("session.completed");
    expect(mistral.type).toBe("session.completed");
    expect(Object.keys(deepgram).sort()).toEqual(Object.keys(mistral).sort());
  });

  it("maps the AI SDK transcription stream into the TimberVox protocol", () => {
    const streamEvent = realtimeTranscriptEventFromStreamPart({
      endSecond: 1.2,
      providerMetadata: {
        timbervox: {
          segments: [
            {
              endSeconds: 1.2,
              startSeconds: 0.8,
              text: "Safety meeting complete.",
            },
          ],
          speakerTurns: [],
          words: [
            {
              confidence: 0.99,
              endSeconds: 1.2,
              speaker: 0,
              startSeconds: 0.8,
              text: "Safety",
            },
          ],
        },
      },
      startSecond: 0.8,
      text: "Safety meeting complete.",
      type: "transcript-final",
    });
    const protocolEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      required(streamEvent)
    );

    expect(required(protocolEvent).type).toBe("transcript.committed");
    expect(required(protocolEvent).words).toEqual([
      {
        confidence: 0.99,
        endSeconds: 1.2,
        speaker: 0,
        startSeconds: 0.8,
        text: "Safety",
      },
    ]);
  });
});
