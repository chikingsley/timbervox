import type { SQLiteDatabase } from "expo-sqlite";

import {
  createMode,
  deleteMode,
  setActiveMode,
  updateMode,
} from "@/features/modes/mode-repository";
import { createModeDraft } from "@/features/modes/preset-contracts";

describe("mode repository", () => {
  it("binds user-controlled values for create, update, activate, and delete", async () => {
    const dangerous = "Robert'); DROP TABLE modes;--";
    const draft = {
      ...createModeDraft("custom", "model-id"),
      description: dangerous,
      id: dangerous,
      name: dangerous,
      processingInstructions: dangerous,
    };
    const calls: Array<{ params: unknown[]; query: string }> = [];
    const row = {
      asr_model_id: draft.asrModelId,
      created_at: "2026-01-01T00:00:00.000Z",
      description: draft.description,
      icon_customized: 0,
      icon_key: draft.iconKey,
      id: draft.id,
      identify_speakers: 0,
      is_active: 0,
      language: null,
      name: draft.name,
      preset_kind: draft.presetKind,
      processing_instructions: draft.processingInstructions,
      processing_model_id: null,
      realtime_enabled: 1,
      updated_at: "2026-01-01T00:00:00.000Z",
    };
    const database = {
      getFirstAsync: jest.fn(async (query: string) => {
        if (query.includes("is_active")) return { id: draft.id, is_active: 0 };
        if (query.includes("SELECT id FROM modes")) return { id: draft.id };
        return row;
      }),
      runAsync: jest.fn(async (query: string, ...params: unknown[]) => {
        calls.push({ params, query });
        return { changes: 1, lastInsertRowId: 1 };
      }),
      withExclusiveTransactionAsync: jest.fn(
        async (task: (transaction: SQLiteDatabase) => Promise<void>) => {
          await task(database as unknown as SQLiteDatabase);
        },
      ),
    } as unknown as SQLiteDatabase;

    await createMode(database, draft);
    await updateMode(database, draft.id, draft);
    await setActiveMode(database, draft.id);
    await deleteMode(database, draft.id);

    expect(calls.some((call) => call.params.includes(dangerous))).toBe(true);
    for (const call of calls) expect(call.query).not.toContain(dangerous);
  });
});
