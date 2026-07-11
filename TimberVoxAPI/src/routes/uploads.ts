import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import { MEDIA_CONTENT_TYPES, normalizedContentType } from "../uploads/limits";
import { completeUpload, createUpload } from "../uploads/service";
import {
  JsonErrorContent,
  UploadCompletionRequest,
  UploadCompletionResponse,
  UploadReservationRequest,
  UploadReservationResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const reserveUploadRoute = createRoute({
  method: "post",
  path: "/v1/uploads",
  request: {
    body: {
      content: { "application/json": { schema: UploadReservationRequest } },
      required: true,
    },
  },
  responses: {
    201: {
      content: { "application/json": { schema: UploadReservationResponse } },
      description: "Direct R2 upload reservation.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    415: { content: JsonErrorContent, description: "Unsupported media type." },
  },
  summary: "Reserve direct R2 upload",
  tags: ["Uploads"],
});

const completeUploadRoute = createRoute({
  method: "post",
  path: "/v1/uploads/{upload_id}/complete",
  request: {
    body: {
      content: { "application/json": { schema: UploadCompletionRequest } },
      required: true,
    },
    params: z.object({ upload_id: z.string().min(1) }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: UploadCompletionResponse } },
      description: "Verified R2 upload.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    404: { content: JsonErrorContent, description: "Upload not found." },
    409: {
      content: JsonErrorContent,
      description: "Uploaded object does not match the reservation.",
    },
  },
  summary: "Complete direct R2 upload",
  tags: ["Uploads"],
});

export const registerUploadRoutes = (app: App): void => {
  app.openapi(reserveUploadRoute, async (c) => {
    const parsed = UploadReservationRequest.safeParse(
      await c.req.json().catch(() => ({}))
    );
    if (!parsed.success) {
      return c.json(
        { error: "invalid request", issues: parsed.error.issues },
        400
      );
    }
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }
    const contentType = normalizedContentType(parsed.data.content_type);
    if (!MEDIA_CONTENT_TYPES.has(contentType)) {
      return c.json({ error: "unsupported media type" }, 415);
    }
    const upload = await createUpload(c.env, {
      contentType,
      credentialId: auth.credentialId,
      filename: parsed.data.filename,
      ownerUserId: auth.userId,
      sizeBytes: parsed.data.size_bytes,
    });
    return c.json(upload, 201);
  });

  app.openapi(completeUploadRoute, async (c) => {
    const parsed = UploadCompletionRequest.safeParse(
      await c.req.json().catch(() => ({}))
    );
    if (!parsed.success) {
      return c.json(
        { error: "invalid request", issues: parsed.error.issues },
        400
      );
    }
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }
    const result = await completeUpload(
      c.env,
      c.req.param("upload_id"),
      auth.userId,
      parsed.data.parts.map((part) => ({
        etag: part.etag,
        partNumber: part.part_number,
      }))
    );
    if (!result) {
      return c.json({ error: "upload not found" }, 404);
    }
    if (result.status === "object_missing") {
      return c.json({ error: "uploaded object was not found in R2" }, 409);
    }
    if (result.status === "invalid_parts") {
      return c.json({ error: "invalid multipart completion manifest" }, 409);
    }
    if (result.status === "size_mismatch") {
      return c.json(
        {
          actual_size_bytes: result.actual_size_bytes,
          declared_size_bytes: result.declared_size_bytes,
          error: "uploaded object size does not match reservation",
        },
        409
      );
    }
    return c.json(
      { input_key: result.input_key, size_bytes: result.size_bytes },
      200
    );
  });
};
