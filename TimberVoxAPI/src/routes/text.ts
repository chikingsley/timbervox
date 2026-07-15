import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";
import { streamSSE } from "hono/streaming";

import {
  runText,
  runTextStream,
  TextRequest,
  type TextResult,
  TextStreamRequest,
} from "../ai/text/service";
import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import {
  JsonErrorContent,
  TextRequestSchema,
  TextResponse,
  TextStreamRequestSchema,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const textRoute = createRoute({
  method: "post",
  path: "/v1/text",
  request: {
    body: {
      content: { "application/json": { schema: TextRequestSchema } },
      required: true,
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: TextResponse } },
      description: "Language-model text or structured result.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
  },
  summary: "Generate text or structured output",
  tags: ["Text"],
});

const textStreamRoute = createRoute({
  method: "post",
  path: "/v1/text/stream",
  request: {
    body: {
      content: { "application/json": { schema: TextStreamRequestSchema } },
      required: true,
    },
  },
  responses: {
    200: {
      content: { "text/event-stream": { schema: z.string() } },
      description:
        "Provider-neutral SSE events: stream.started, text.delta, then stream.completed or stream.failed.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
  },
  summary: "Stream text generation",
  tags: ["Text"],
});

const executeText = async (
  env: Env,
  authorization: string | undefined,
  request: TextRequest
): Promise<TextResult | null> => {
  const auth = await authenticateCredential(env, authorization);
  return auth
    ? runText(env, request, {
        credentialId: auth.credentialId,
        userId: auth.userId,
      })
    : null;
};

export const registerTextRoutes = (app: App): void => {
  app.openapi(textRoute, async (c) => {
    const result = await executeText(
      c.env,
      c.req.header("authorization"),
      TextRequest.parse(c.req.valid("json"))
    );
    if (!result) {
      return c.json({ error: "unauthorized" }, 401);
    }
    return c.json(result, 200);
  });
  app.openapi(textStreamRoute, async (c) => {
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }
    const request = TextStreamRequest.parse(c.req.valid("json"));
    return streamSSE(c, async (stream) => {
      await runTextStream(
        c.env,
        request,
        { credentialId: auth.credentialId, userId: auth.userId },
        async (event) => {
          await stream.writeSSE({
            data: JSON.stringify(event),
            event: event.type,
            id: String(event.sequence),
          });
        }
      );
    });
  });
};
