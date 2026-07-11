import type { Env } from "../../bindings";
import { publicModelCatalog } from "../models/catalog";
import { providerInventoryAdapters } from "./adapters";
import { compareCatalogToInventory } from "./compare";
import type { ProviderInventoryReport } from "./types";

export const getProviderInventory = async (
  env: Env,
  fetchImpl: typeof fetch = fetch,
  now: Date = new Date()
): Promise<ProviderInventoryReport> => {
  const sources = await Promise.all(
    providerInventoryAdapters.map((adapter) =>
      adapter.list({ env, fetch: fetchImpl, now })
    )
  );
  const catalog = publicModelCatalog();
  return {
    catalog,
    checkedAt: now.toISOString(),
    drift: compareCatalogToInventory(catalog, sources),
    sources,
  };
};
