import type { SQLiteDatabase } from "expo-sqlite";

import type { Mode, ModeDraft } from "@/features/modes/mode-types";

type ModeRow = {
  asr_model_id: string;
  created_at: string;
  description: string;
  icon_customized: number;
  icon_key: string;
  id: string;
  identify_speakers: number;
  is_active: number;
  language: string | null;
  name: string;
  preset_kind: Mode["presetKind"];
  processing_instructions: string | null;
  processing_model_id: string | null;
  realtime_enabled: number;
  updated_at: string;
};

const MODE_COLUMNS = `
  id, name, icon_key, icon_customized, description, preset_kind,
  language, asr_model_id, realtime_enabled, identify_speakers,
  processing_model_id, processing_instructions, is_active,
  created_at, updated_at
`;

function mapMode(row: ModeRow): Mode {
  return {
    asrModelId: row.asr_model_id,
    createdAt: row.created_at,
    description: row.description,
    iconCustomized: row.icon_customized === 1,
    iconKey: row.icon_key,
    id: row.id,
    identifySpeakers: row.identify_speakers === 1,
    isActive: row.is_active === 1,
    language: row.language,
    name: row.name,
    presetKind: row.preset_kind,
    processingInstructions: row.processing_instructions,
    processingModelId: row.processing_model_id,
    realtimeEnabled: row.realtime_enabled === 1,
    updatedAt: row.updated_at,
  };
}

async function listModes(database: SQLiteDatabase) {
  const rows = await database.getAllAsync<ModeRow>(
    `SELECT ${MODE_COLUMNS} FROM modes ORDER BY is_active DESC, updated_at DESC`,
  );
  return rows.map(mapMode);
}

async function getMode(database: SQLiteDatabase, id: string) {
  const row = await database.getFirstAsync<ModeRow>(
    `SELECT ${MODE_COLUMNS} FROM modes WHERE id = ?`,
    id,
  );
  return row ? mapMode(row) : null;
}

async function createMode(database: SQLiteDatabase, draft: ModeDraft) {
  const now = new Date().toISOString();
  await database.withExclusiveTransactionAsync(async (transaction) => {
    await transaction.runAsync(
      `INSERT INTO modes (
        id, name, icon_key, icon_customized, description, preset_kind,
        language, asr_model_id, realtime_enabled, identify_speakers,
        processing_model_id, processing_instructions, is_active,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      draft.id,
      draft.name,
      draft.iconKey,
      draft.iconCustomized ? 1 : 0,
      draft.description,
      draft.presetKind,
      draft.language,
      draft.asrModelId,
      draft.realtimeEnabled ? 1 : 0,
      draft.identifySpeakers ? 1 : 0,
      draft.processingModelId,
      draft.processingInstructions,
      0,
      now,
      now,
    );
  });
  const created = await getMode(database, draft.id);
  if (!created) throw new Error("The mode could not be created.");
  return created;
}

async function updateMode(
  database: SQLiteDatabase,
  id: string,
  draft: ModeDraft,
) {
  await database.withExclusiveTransactionAsync(async (transaction) => {
    const result = await transaction.runAsync(
      `UPDATE modes SET
        name = ?, icon_key = ?, icon_customized = ?, description = ?,
        preset_kind = ?, language = ?, asr_model_id = ?,
        realtime_enabled = ?, identify_speakers = ?, processing_model_id = ?,
        processing_instructions = ?, updated_at = ?
       WHERE id = ?`,
      draft.name,
      draft.iconKey,
      draft.iconCustomized ? 1 : 0,
      draft.description,
      draft.presetKind,
      draft.language,
      draft.asrModelId,
      draft.realtimeEnabled ? 1 : 0,
      draft.identifySpeakers ? 1 : 0,
      draft.processingModelId,
      draft.processingInstructions,
      new Date().toISOString(),
      id,
    );
    if (result.changes !== 1) throw new Error("The mode no longer exists.");
  });
  const updated = await getMode(database, id);
  if (!updated) throw new Error("The mode could not be updated.");
  return updated;
}

async function setActiveMode(database: SQLiteDatabase, id: string) {
  await database.withExclusiveTransactionAsync(async (transaction) => {
    const candidate = await transaction.getFirstAsync<{ id: string }>(
      "SELECT id FROM modes WHERE id = ?",
      id,
    );
    if (!candidate) throw new Error("The selected mode no longer exists.");

    await transaction.runAsync(
      "UPDATE modes SET is_active = 0 WHERE is_active = 1",
    );
    await transaction.runAsync(
      "UPDATE modes SET is_active = 1, updated_at = ? WHERE id = ?",
      new Date().toISOString(),
      id,
    );
    await transaction.runAsync(
      `INSERT INTO app_settings (key, value_json, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET
         value_json = excluded.value_json,
         updated_at = excluded.updated_at`,
      "active_mode_id",
      JSON.stringify(id),
      new Date().toISOString(),
    );
  });
}

async function deleteMode(
  database: SQLiteDatabase,
  id: string,
  replacementId?: string,
) {
  await database.withExclusiveTransactionAsync(async (transaction) => {
    const candidate = await transaction.getFirstAsync<{
      id: string;
      is_active: number;
    }>("SELECT id, is_active FROM modes WHERE id = ?", id);
    if (!candidate) return;

    if (candidate.is_active === 1) {
      if (!replacementId || replacementId === id) {
        throw new Error("Choose another active mode before deleting this one.");
      }
      const replacement = await transaction.getFirstAsync<{ id: string }>(
        "SELECT id FROM modes WHERE id = ?",
        replacementId,
      );
      if (!replacement)
        throw new Error("The replacement mode no longer exists.");
      await transaction.runAsync(
        "UPDATE modes SET is_active = 0 WHERE id = ?",
        id,
      );
      await transaction.runAsync(
        "UPDATE modes SET is_active = 1, updated_at = ? WHERE id = ?",
        new Date().toISOString(),
        replacementId,
      );
      await transaction.runAsync(
        `UPDATE app_settings SET value_json = ?, updated_at = ?
         WHERE key = ?`,
        JSON.stringify(replacementId),
        new Date().toISOString(),
        "active_mode_id",
      );
    }
    await transaction.runAsync("DELETE FROM modes WHERE id = ?", id);
  });
}

export {
  createMode,
  deleteMode,
  getMode,
  listModes,
  mapMode,
  setActiveMode,
  updateMode,
};
