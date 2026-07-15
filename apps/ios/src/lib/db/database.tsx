import { SQLiteProvider, type SQLiteDatabase } from "expo-sqlite";
import type { PropsWithChildren } from "react";

const DATABASE_NAME = "timbervox-mobile.db";

const VOICE_MODE_ID = "mode_voice_default";
const VOICE_DESCRIPTION =
  "Turn your voice into punctuated text with no AI post-processing.";

type Migration = {
  migrate: (database: SQLiteDatabase) => Promise<void>;
  version: number;
};

const migrations: Migration[] = [
  {
    version: 1,
    migrate: async (database) => {
      await database.execAsync(`
        CREATE TABLE IF NOT EXISTS dictation_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          text TEXT NOT NULL,
          duration_ms INTEGER NOT NULL,
          model TEXT NOT NULL,
          source TEXT NOT NULL,
          audio_uri TEXT
        );

        CREATE TABLE IF NOT EXISTS modes (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          icon_key TEXT NOT NULL,
          icon_customized INTEGER NOT NULL DEFAULT 0 CHECK (icon_customized IN (0, 1)),
          description TEXT NOT NULL,
          preset_kind TEXT NOT NULL CHECK (
            preset_kind IN ('voice', 'message', 'mail', 'note', 'custom')
          ),
          language TEXT,
          asr_model_id TEXT NOT NULL,
          realtime_enabled INTEGER NOT NULL CHECK (realtime_enabled IN (0, 1)),
          identify_speakers INTEGER NOT NULL CHECK (identify_speakers IN (0, 1)),
          processing_model_id TEXT,
          processing_instructions TEXT,
          is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE UNIQUE INDEX IF NOT EXISTS modes_single_active
          ON modes (is_active)
          WHERE is_active = 1;

        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY NOT NULL,
          value_json TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      `);

      const now = new Date().toISOString();
      await database.runAsync(
        `INSERT INTO modes (
          id, name, icon_key, icon_customized, description, preset_kind,
          language, asr_model_id, realtime_enabled, identify_speakers,
          processing_model_id, processing_instructions, is_active,
          created_at, updated_at
        )
        SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        WHERE NOT EXISTS (SELECT 1 FROM modes)`,
        VOICE_MODE_ID,
        "Voice to Text",
        "person.wave.2.fill",
        0,
        VOICE_DESCRIPTION,
        "voice",
        null,
        "",
        1,
        0,
        null,
        null,
        1,
        now,
        now,
      );
      await database.runAsync(
        `INSERT INTO app_settings (key, value_json, updated_at)
         SELECT ?, ?, ?
         WHERE EXISTS (SELECT 1 FROM modes WHERE id = ?)
           AND NOT EXISTS (SELECT 1 FROM app_settings WHERE key = ?)`,
        "active_mode_id",
        JSON.stringify(VOICE_MODE_ID),
        now,
        VOICE_MODE_ID,
        "active_mode_id",
      );
    },
  },
  {
    version: 2,
    migrate: async (database) => {
      await database.runAsync(
        `UPDATE modes
         SET name = ?, updated_at = ?
         WHERE preset_kind = ? AND name = ?`,
        "Voice to Text",
        new Date().toISOString(),
        "voice",
        "Voice",
      );
    },
  },
];

async function migrateDatabase(database: SQLiteDatabase) {
  await database.execAsync("PRAGMA journal_mode = WAL");
  await database.execAsync("PRAGMA foreign_keys = ON");
  await database.execAsync(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INTEGER PRIMARY KEY NOT NULL,
      applied_at TEXT NOT NULL
    );
  `);

  for (const migration of migrations) {
    const applied = await database.getFirstAsync<{ version: number }>(
      "SELECT version FROM schema_migrations WHERE version = ?",
      migration.version,
    );
    if (applied) continue;

    await database.withExclusiveTransactionAsync(async (transaction) => {
      const alreadyApplied = await transaction.getFirstAsync<{
        version: number;
      }>(
        "SELECT version FROM schema_migrations WHERE version = ?",
        migration.version,
      );
      if (alreadyApplied) return;
      await migration.migrate(transaction);
      await transaction.runAsync(
        "INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)",
        migration.version,
        new Date().toISOString(),
      );
    });
  }
}

function AppDatabaseProvider({ children }: PropsWithChildren) {
  return (
    <SQLiteProvider databaseName={DATABASE_NAME} onInit={migrateDatabase}>
      {children}
    </SQLiteProvider>
  );
}

export {
  AppDatabaseProvider,
  DATABASE_NAME,
  migrateDatabase,
  migrations,
  VOICE_MODE_ID,
};
