export type ModePresetKind = "voice" | "message" | "mail" | "note" | "custom";

export type Mode = {
  asrModelId: string;
  createdAt: string;
  description: string;
  iconCustomized: boolean;
  iconKey: string;
  id: string;
  identifySpeakers: boolean;
  isActive: boolean;
  language: string | null;
  name: string;
  presetKind: ModePresetKind;
  processingInstructions: string | null;
  processingModelId: string | null;
  realtimeEnabled: boolean;
  updatedAt: string;
};

export type ModeDraft = Omit<Mode, "createdAt" | "isActive" | "updatedAt">;
