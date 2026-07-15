import type { SQLiteDatabase } from "expo-sqlite";

import { migrateDatabase, migrations } from "@/lib/db/database";

describe("mobile database migrations", () => {
  it("applies every migration once and is idempotent on relaunch", async () => {
    const applied = new Set<number>();
    let seedCount = 0;
    const database = {
      execAsync: jest.fn(async () => undefined),
      getFirstAsync: jest.fn(async (_query: string, version: number) =>
        applied.has(version) ? { version } : null,
      ),
      runAsync: jest.fn(async (query: string, ...params: unknown[]) => {
        if (query.includes("INSERT INTO modes")) seedCount += 1;
        if (query.includes("INSERT INTO schema_migrations")) {
          applied.add(params[0] as number);
        }
        return { changes: 1, lastInsertRowId: 1 };
      }),
      withExclusiveTransactionAsync: jest.fn(
        async (task: (transaction: SQLiteDatabase) => Promise<void>) => {
          await task(database as unknown as SQLiteDatabase);
        },
      ),
    } as unknown as SQLiteDatabase;

    await migrateDatabase(database);
    await migrateDatabase(database);

    expect([...applied]).toEqual(
      migrations.map((migration) => migration.version),
    );
    expect(seedCount).toBe(1);
  });
});
