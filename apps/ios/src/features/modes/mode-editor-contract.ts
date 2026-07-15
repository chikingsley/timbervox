import type { ModePresetKind } from "@/features/modes/mode-types";

const MODE_ICON_COLUMNS = 8;

const MODE_ICONS = [
  "person.wave.2.fill",
  "message.fill",
  "envelope.fill",
  "note.text",
  "slider.horizontal.3",
  "mic.fill",
  "waveform",
  "quote.bubble.fill",
  "text.bubble.fill",
  "bolt.fill",
  "sparkles",
  "wand.and.stars",
  "brain.head.profile",
  "lightbulb.fill",
  "book.fill",
  "briefcase.fill",
  "graduationcap.fill",
  "stethoscope",
  "hammer.fill",
  "paintbrush.fill",
  "terminal.fill",
  "globe",
  "star.fill",
  "heart.fill",
  "checklist",
  "list.bullet.rectangle",
  "calendar",
  "person.2.fill",
  "megaphone.fill",
  "paperplane.fill",
] as const;

type OptionalModeField = "identifySpeakers" | "instructions" | "languageModel";
type ExistingModeEditorState = "loading" | "missing" | "ready";

function existingModeEditorState({
  draftId,
  modeId,
  modesLoading,
  storedModeExists,
}: {
  draftId?: string;
  modeId?: string;
  modesLoading: boolean;
  storedModeExists: boolean;
}): ExistingModeEditorState {
  if (!modeId || (!modesLoading && !storedModeExists)) return "missing";
  if (storedModeExists && draftId === modeId) return "ready";
  return "loading";
}

function optionalModeFields({
  presetKind,
  supportsDiarization,
}: {
  presetKind: ModePresetKind;
  supportsDiarization: boolean;
}): OptionalModeField[] {
  const usesProcessing = presetKind !== "voice";
  return [
    ...(supportsDiarization ? (["identifySpeakers"] as const) : []),
    ...(usesProcessing ? (["languageModel"] as const) : []),
    ...(presetKind === "custom" ? (["instructions"] as const) : []),
  ];
}

export {
  existingModeEditorState,
  MODE_ICON_COLUMNS,
  MODE_ICONS,
  optionalModeFields,
};
export type { ExistingModeEditorState, OptionalModeField };
