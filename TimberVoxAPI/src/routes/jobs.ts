import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import { getOwnedJob, jobView } from "../jobs/db";
import { JobView, JsonErrorContent } from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const getJobRoute = createRoute({
  method: "get",
  path: "/v1/jobs/{job_id}",
  request: {
    params: z.object({
      job_id: z.string().min(1),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: JobView } },
      description: "Job state and canonical result JSON.",
    },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    404: { content: JsonErrorContent, description: "Job not found." },
  },
  summary: "Get job",
  tags: ["Jobs"],
});

export const registerJobRoutes = (app: App): void => {
  app.openapi(getJobRoute, async (c) => {
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }
    const job = await getOwnedJob(c.env, c.req.param("job_id"), auth.userId);
    if (!job) {
      return c.json({ error: "job not found" }, 404);
    }
    return c.json(jobView(job), 200);
  });
};
