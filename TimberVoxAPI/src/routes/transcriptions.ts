import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import {
  createTranscription,
  TranscriptionRequest,
} from "../jobs/transcriptions";
import {
  JobView,
  JsonErrorContent,
  TranscriptionRequestSchema,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const createTranscriptionRoute = createRoute({
  method: "post",
  path: "/v1/transcriptions",
  request: {
    body: {
      content: { "application/json": { schema: TranscriptionRequestSchema } },
      required: true,
    },
    headers: z.object({
      "idempotency-key": z.string().optional(),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: JobView } },
      description: "Existing idempotent job.",
    },
    202: {
      content: { "application/json": { schema: JobView } },
      description: "Queued transcription job.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    404: { content: JsonErrorContent, description: "Upload not found." },
  },
  summary: "Create transcription job",
  tags: ["Transcriptions"],
});

export const registerTranscriptionRoutes = (app: App): void => {
  app.openapi(createTranscriptionRoute, async (c) => {
    const parsed = TranscriptionRequest.parse(c.req.valid("json"));
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }
    try {
      const result = await createTranscription(c.env, parsed, {
        auth,
        idempotencyKey: c.req.header("idempotency-key") ?? undefined,
      });
      return c.json(result.view, result.status);
    } catch (error) {
      if (error instanceof Error && error.message === "upload not found") {
        return c.json({ error: error.message }, 404);
      }
      throw error;
    }
  });
};
