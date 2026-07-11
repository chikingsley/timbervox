import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { publicModelCatalog } from "../ai/models/catalog";
import type { PublicAsrRouteSpec, PublicModelSpec } from "../ai/models/types";
import type { Env } from "../bindings";

type App = OpenAPIHono<{ Bindings: Env }>;

const AsrRouteSpec = z
  .object({
    model: z.string(),
    provider: z.string(),
    supported_languages: z.array(z.string()),
    supports_automatic_language: z.boolean(),
    supports_diarization: z.boolean(),
    upstream_model: z.string(),
  })
  .openapi("AsrRouteSpec");

const ModelSpec = z
  .object({
    id: z.string(),
    kind: z.enum(["language", "transcription"]),
    provider: z.string(),
    routes: z
      .object({
        batch: AsrRouteSpec.optional(),
        realtime: AsrRouteSpec.optional(),
      })
      .optional(),
    upstream_model: z.string(),
  })
  .openapi("ModelSpec");

const ModelsResponse = z
  .object({
    models: z.array(ModelSpec),
  })
  .openapi("ModelsResponse");

const modelsRoute = createRoute({
  method: "get",
  path: "/v1/models",
  responses: {
    200: {
      content: { "application/json": { schema: ModelsResponse } },
      description: "Supported TimberVox model catalog.",
    },
  },
  summary: "List supported models",
  tags: ["Models"],
});

const routeView = (route: PublicAsrRouteSpec | undefined) =>
  route
    ? {
        model: route.model,
        provider: route.provider,
        supported_languages: [...route.supportedLanguages],
        supports_automatic_language: route.supportsAutomaticLanguage,
        supports_diarization: route.supportsDiarization,
        upstream_model: route.upstreamModel,
      }
    : undefined;

const routesView = (routes: PublicModelSpec["routes"]) =>
  routes
    ? {
        batch: routeView(routes.batch),
        realtime: routeView(routes.realtime),
      }
    : undefined;

const modelView = (model: PublicModelSpec) => ({
  id: model.id,
  kind: model.kind,
  provider: model.provider,
  routes: routesView(model.routes),
  upstream_model: model.upstreamModel,
});

const providerIsConfigured = (env: Env, provider: string): boolean => {
  switch (provider) {
    case "anthropic":
      return Boolean(env.ANTHROPIC_API_KEY);
    case "cerebras":
      return Boolean(env.CEREBRAS_API_KEY);
    case "deepgram":
      return Boolean(env.DEEPGRAM_API_KEY);
    case "deepseek":
      return Boolean(env.DEEPSEEK_API_KEY);
    case "elevenlabs":
      return Boolean(env.ELEVENLABS_API_KEY);
    case "google":
      return Boolean(env.GOOGLE_GENERATIVE_AI_API_KEY);
    case "groq":
      return Boolean(env.GROQ_API_KEY);
    case "mistral":
      return Boolean(env.MISTRAL_API_KEY);
    case "openai":
      return Boolean(env.OPENAI_API_KEY);
    case "zai":
      return Boolean(env.ZAI_API_KEY);
    default:
      return false;
  }
};

export const registerModelRoutes = (app: App): void => {
  app.openapi(modelsRoute, (c) =>
    c.json(
      {
        models: publicModelCatalog()
          .filter((model) => providerIsConfigured(c.env, model.provider))
          .map(modelView),
      },
      200
    )
  );
};
