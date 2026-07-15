import { Directory, File, Paths } from "expo-file-system";
import { useSQLiteContext } from "expo-sqlite";
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

const recordingsDirectory = new Directory(Paths.document, "recordings");

export type DictationHistoryItem = {
  audioUri: string | null;
  createdAt: string;
  durationMs: number;
  id: number;
  model: string;
  source: "app" | "keyboard";
  text: string;
};

type NewDictationHistoryItem = {
  audioChunks: ArrayBuffer[];
  durationMs: number;
  model: string;
  source: "app" | "keyboard";
  text: string;
};

type HistoryValue = {
  add: (item: NewDictationHistoryItem) => Promise<DictationHistoryItem>;
  items: DictationHistoryItem[];
  reload: () => Promise<void>;
  remove: (item: DictationHistoryItem) => Promise<void>;
};

const HistoryContext = createContext<HistoryValue | null>(null);

export function HistoryProvider({ children }: PropsWithChildren) {
  const database = useSQLiteContext();
  const [items, setItems] = useState<DictationHistoryItem[]>([]);

  const reload = useCallback(async () => {
    setItems(await loadHistory(database));
  }, [database]);

  useEffect(() => {
    let mounted = true;
    void loadHistory(database).then((stored) => {
      if (mounted) setItems(stored);
    });
    return () => {
      mounted = false;
    };
  }, [database]);

  const add = useCallback(
    async (item: NewDictationHistoryItem) => {
      const createdAt = new Date().toISOString();
      const audioUri = writeRecording(item.audioChunks, createdAt);
      const result = await database.runAsync(
        `INSERT INTO dictation_history
          (created_at, text, duration_ms, model, source, audio_uri)
         VALUES (?, ?, ?, ?, ?, ?)`,
        createdAt,
        item.text,
        item.durationMs,
        item.model,
        item.source,
        audioUri,
      );
      const saved: DictationHistoryItem = {
        audioUri,
        createdAt,
        durationMs: item.durationMs,
        id: Number(result.lastInsertRowId),
        model: item.model,
        source: item.source,
        text: item.text,
      };
      setItems((current) => [saved, ...current]);
      return saved;
    },
    [database],
  );

  const remove = useCallback(
    async (item: DictationHistoryItem) => {
      await database.runAsync(
        "DELETE FROM dictation_history WHERE id = ?",
        item.id,
      );
      if (item.audioUri) {
        const file = new File(item.audioUri);
        if (file.exists) file.delete();
      }
      setItems((current) =>
        current.filter((candidate) => candidate.id !== item.id),
      );
    },
    [database],
  );

  const value = useMemo(
    () => ({ add, items, reload, remove }),
    [add, items, reload, remove],
  );
  return (
    <HistoryContext.Provider value={value}>{children}</HistoryContext.Provider>
  );
}

export function useHistory() {
  const value = useContext(HistoryContext);
  if (!value) throw new Error("useHistory must be used inside HistoryProvider");
  return value;
}

async function loadHistory(database: ReturnType<typeof useSQLiteContext>) {
  const rows = await database.getAllAsync<{
    audio_uri: string | null;
    created_at: string;
    duration_ms: number;
    id: number;
    model: string;
    source: "app" | "keyboard";
    text: string;
  }>("SELECT * FROM dictation_history ORDER BY created_at DESC");
  return rows.map((row) => ({
    audioUri: row.audio_uri,
    createdAt: row.created_at,
    durationMs: row.duration_ms,
    id: row.id,
    model: row.model,
    source: row.source,
    text: row.text,
  }));
}

function writeRecording(chunks: ArrayBuffer[], createdAt: string) {
  if (chunks.length === 0) return null;
  recordingsDirectory.create({ idempotent: true, intermediates: true });
  const filename = `${createdAt.replaceAll(":", "-")}.wav`;
  const file = new File(recordingsDirectory, filename);
  file.create({ overwrite: true, intermediates: true });
  file.write(makeWaveFile(chunks));
  return file.uri;
}

function makeWaveFile(chunks: ArrayBuffer[]) {
  const dataLength = chunks.reduce(
    (total, chunk) => total + chunk.byteLength,
    0,
  );
  const output = new Uint8Array(44 + dataLength);
  const view = new DataView(output.buffer);
  writeAscii(view, 0, "RIFF");
  view.setUint32(4, 36 + dataLength, true);
  writeAscii(view, 8, "WAVE");
  writeAscii(view, 12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, 16_000, true);
  view.setUint32(28, 32_000, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeAscii(view, 36, "data");
  view.setUint32(40, dataLength, true);
  let offset = 44;
  for (const chunk of chunks) {
    output.set(new Uint8Array(chunk), offset);
    offset += chunk.byteLength;
  }
  return output;
}

function writeAscii(view: DataView, offset: number, value: string) {
  for (let index = 0; index < value.length; index += 1) {
    view.setUint8(offset + index, value.charCodeAt(index));
  }
}
