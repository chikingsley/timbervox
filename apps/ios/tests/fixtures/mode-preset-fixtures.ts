import type { ModePresetKind } from "@/features/modes/mode-types";
import type { PresetProcessingRequest } from "@/features/modes/preset-contracts";

type ModePresetFixture = {
  displayedArtifact: string;
  expectedRequest: PresetProcessingRequest | null;
  inputTranscript: string;
  presetKind: ModePresetKind;
  processingInstructions: string | null;
  processingModelId: string | null;
  transformedText?: string;
};

const inputTranscript =
  "Hey Sam, I can send the revised draft tomorrow morning after I check the figures.";
const processingModelId = "mistral-mistral-medium-latest";

const MODE_PRESET_FIXTURES: ModePresetFixture[] = [
  {
    displayedArtifact: inputTranscript,
    expectedRequest: null,
    inputTranscript,
    presetKind: "voice",
    processingInstructions: null,
    processingModelId: null,
  },
  {
    displayedArtifact:
      "Hey Sam — I’ll send the revised draft tomorrow morning after I check the figures.",
    expectedRequest: {
      messages: [
        {
          content:
            "Rewrite the transcript as a concise conversational message. Preserve intent and do not invent facts.",
          role: "system",
        },
        { content: inputTranscript, role: "user" },
      ],
      model: processingModelId,
      temperature: 0,
    },
    inputTranscript,
    presetKind: "message",
    processingInstructions:
      "Rewrite the transcript as a concise conversational message. Preserve intent and do not invent facts.",
    processingModelId,
    transformedText:
      "Hey Sam — I’ll send the revised draft tomorrow morning after I check the figures.",
  },
  {
    displayedArtifact:
      "Hi Sam,\n\nI’ll send the revised draft tomorrow morning after I check the figures.\n\nBest,",
    expectedRequest: {
      messages: [
        {
          content:
            "Rewrite the transcript as a clear email. Preserve intent, add only structural email conventions, and do not invent facts.",
          role: "system",
        },
        { content: inputTranscript, role: "user" },
      ],
      model: processingModelId,
      temperature: 0,
    },
    inputTranscript,
    presetKind: "mail",
    processingInstructions:
      "Rewrite the transcript as a clear email. Preserve intent, add only structural email conventions, and do not invent facts.",
    processingModelId,
    transformedText:
      "Hi Sam,\n\nI’ll send the revised draft tomorrow morning after I check the figures.\n\nBest,",
  },
  {
    displayedArtifact:
      "Revised draft\n\n- Check the figures.\n- Send the draft to Sam tomorrow morning.",
    expectedRequest: {
      messages: [
        {
          content:
            "Organize the transcript into a readable note. Preserve every material idea and do not invent facts.",
          role: "system",
        },
        { content: inputTranscript, role: "user" },
      ],
      model: processingModelId,
      temperature: 0,
    },
    inputTranscript,
    presetKind: "note",
    processingInstructions:
      "Organize the transcript into a readable note. Preserve every material idea and do not invent facts.",
    processingModelId,
    transformedText:
      "Revised draft\n\n- Check the figures.\n- Send the draft to Sam tomorrow morning.",
  },
  {
    displayedArtifact:
      "Tomorrow morning: verify the figures, then send Sam the revised draft.",
    expectedRequest: {
      messages: [
        {
          content: "Rewrite this as one action-oriented sentence.",
          role: "system",
        },
        { content: inputTranscript, role: "user" },
      ],
      model: processingModelId,
      temperature: 0,
    },
    inputTranscript,
    presetKind: "custom",
    processingInstructions: "Rewrite this as one action-oriented sentence.",
    processingModelId,
    transformedText:
      "Tomorrow morning: verify the figures, then send Sam the revised draft.",
  },
];

export { MODE_PRESET_FIXTURES };
