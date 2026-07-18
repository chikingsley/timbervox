import { describe, expect, it } from "vitest";

import type { Env } from "../../src/bindings";
import { app } from "../../src/index";

const protectedFrameworkPaths = ["/health", "/docs", "/openapi.json"];
const testEnv = {
  TIMBERVOX_API_KEYS: "test-api-key",
} as Env;

describe("global HTTP API-key gate", () => {
  for (const path of protectedFrameworkPaths) {
    it(`rejects unauthenticated ${path}`, async () => {
      const response = await app.request(path, undefined, testEnv);
      expect(response.status).toBe(401);
      expect(await response.json()).toEqual({ error: "unauthorized" });
    });

    it(`accepts an authenticated request to ${path}`, async () => {
      const response = await app.request(
        path,
        { headers: { Authorization: "Bearer test-api-key" } },
        testEnv
      );
      expect(response.status).toBe(200);
    });
  }
});
