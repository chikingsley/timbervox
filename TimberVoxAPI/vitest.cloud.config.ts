import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/cloud/**/*.test.ts"],
    testTimeout: 15_000,
  },
});
