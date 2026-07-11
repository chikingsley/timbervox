import type { Env } from "../bindings";
import { newId } from "../lib/ids";
import { multipartPartSize, SINGLE_PUT_THRESHOLD_BYTES } from "./limits";
import { signR2PutUrl } from "./signing";

const nowIso = (): string => new Date().toISOString();

type UploadStrategy = "multipart" | "single";

interface UploadRow {
  completed_at: string | null;
  content_type: string;
  declared_size_bytes: number;
  input_key: string;
  multipart_upload_id: string | null;
  size_bytes: number | null;
  upload_strategy: UploadStrategy;
}

export const createUpload = async (
  env: Env,
  input: {
    contentType: string;
    credentialId: string;
    filename?: string;
    ownerUserId: string;
    sizeBytes: number;
  }
) => {
  const id = newId("upl");
  const inputKey = `uploads/${id}/source`;
  const strategy: UploadStrategy =
    input.sizeBytes <= SINGLE_PUT_THRESHOLD_BYTES ? "single" : "multipart";
  const multipartUpload =
    strategy === "multipart"
      ? await env.ARTIFACTS.createMultipartUpload(inputKey, {
          httpMetadata: { contentType: input.contentType },
        })
      : null;

  try {
    await env.DB.prepare(
      `INSERT INTO uploads
        (id, input_key, filename, content_type, owner_user_id, credential_id,
         declared_size_bytes, upload_strategy, multipart_upload_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        id,
        inputKey,
        input.filename ?? null,
        input.contentType,
        input.ownerUserId,
        input.credentialId,
        input.sizeBytes,
        strategy,
        multipartUpload?.uploadId ?? null,
        nowIso()
      )
      .run();

    return {
      input_key: inputKey,
      transfer:
        strategy === "single"
          ? await singleTransfer(env, inputKey, input.contentType)
          : await multipartTransfer(
              env,
              inputKey,
              input.sizeBytes,
              multipartUpload?.uploadId ?? ""
            ),
      upload_id: id,
    };
  } catch (error) {
    await multipartUpload?.abort();
    throw error;
  }
};

const singleTransfer = async (
  env: Env,
  inputKey: string,
  contentType: string
) => {
  const signed = await signR2PutUrl(env, inputKey, { contentType });
  return {
    headers: signed.headers,
    kind: "single" as const,
    url: signed.url,
  };
};

const multipartTransfer = async (
  env: Env,
  inputKey: string,
  sizeBytes: number,
  uploadId: string
) => {
  if (!uploadId) {
    throw new Error("missing R2 multipart upload ID");
  }
  const partSizeBytes = multipartPartSize(sizeBytes);
  const partCount = Math.ceil(sizeBytes / partSizeBytes);
  const partNumbers = Array.from(
    { length: partCount },
    (_, index) => index + 1
  );
  const parts = await Promise.all(
    partNumbers.map(async (partNumber) => {
      const signed = await signR2PutUrl(env, inputKey, {
        partNumber,
        uploadId,
      });
      return {
        headers: signed.headers,
        part_number: partNumber,
        url: signed.url,
      };
    })
  );
  return {
    kind: "multipart" as const,
    part_size_bytes: partSizeBytes,
    parts,
  };
};

export const completeUpload = async (
  env: Env,
  uploadId: string,
  ownerUserId: string,
  parts: readonly { etag: string; partNumber: number }[]
) => {
  const row = await uploadRow(env, uploadId, ownerUserId);
  if (!row) {
    return null;
  }
  if (row.completed_at && row.size_bytes !== null) {
    return completedResult(row.input_key, row.size_bytes);
  }

  let object: R2Object | null;
  if (row.upload_strategy === "single") {
    object = await env.ARTIFACTS.head(row.input_key);
  } else {
    const normalizedParts = normalizedMultipartParts(row, parts);
    if (!normalizedParts) {
      return { status: "invalid_parts" as const };
    }
    object = await completeMultipartUpload(env, row, normalizedParts);
  }
  if (!object) {
    return { status: "object_missing" as const };
  }
  if (object.size !== row.declared_size_bytes) {
    await env.ARTIFACTS.delete(row.input_key);
    return {
      actual_size_bytes: object.size,
      declared_size_bytes: row.declared_size_bytes,
      status: "size_mismatch" as const,
    };
  }

  await env.DB.prepare(
    `UPDATE uploads
        SET size_bytes = ?, completed_at = ?
      WHERE input_key = ?`
  )
    .bind(object.size, nowIso(), row.input_key)
    .run();
  return completedResult(row.input_key, object.size);
};

const completeMultipartUpload = async (
  env: Env,
  row: UploadRow,
  parts: { etag: string; partNumber: number }[]
): Promise<R2Object> => {
  if (!row.multipart_upload_id) {
    throw new Error("missing R2 multipart upload ID");
  }
  return await env.ARTIFACTS.resumeMultipartUpload(
    row.input_key,
    row.multipart_upload_id
  ).complete(parts);
};

const normalizedMultipartParts = (
  row: UploadRow,
  parts: readonly { etag: string; partNumber: number }[]
): { etag: string; partNumber: number }[] | null => {
  const expectedPartCount = Math.ceil(
    row.declared_size_bytes / multipartPartSize(row.declared_size_bytes)
  );
  const normalizedParts = [...parts]
    .sort((left, right) => left.partNumber - right.partNumber)
    .map((part) => ({
      etag: part.etag.replace(/^"|"$/g, ""),
      partNumber: part.partNumber,
    }));
  const hasExpectedParts =
    normalizedParts.length === expectedPartCount &&
    normalizedParts.every(
      (part, index) => part.partNumber === index + 1 && part.etag.length > 0
    );
  if (!hasExpectedParts) {
    return null;
  }
  return normalizedParts;
};

const uploadRow = (
  env: Env,
  uploadId: string,
  ownerUserId: string
): Promise<UploadRow | null> =>
  env.DB.prepare(
    `SELECT input_key, content_type, declared_size_bytes, size_bytes,
            upload_strategy, multipart_upload_id, completed_at
       FROM uploads
      WHERE id = ?
        AND owner_user_id = ?`
  )
    .bind(uploadId, ownerUserId)
    .first<UploadRow>();

const completedResult = (inputKey: string, sizeBytes: number) => ({
  input_key: inputKey,
  size_bytes: sizeBytes,
  status: "completed" as const,
});

export const completedUpload = async (
  env: Env,
  inputKey: string,
  ownerUserId: string
): Promise<{
  contentType: string;
  filename: string;
  inputKey: string;
  sizeBytes: number;
} | null> => {
  const row = await env.DB.prepare(
    `SELECT input_key, content_type, filename, size_bytes
       FROM uploads
      WHERE input_key = ?
        AND owner_user_id = ?
        AND completed_at IS NOT NULL`
  )
    .bind(inputKey, ownerUserId)
    .first<{
      content_type: string;
      filename: string | null;
      input_key: string;
      size_bytes: number;
    }>();
  return row
    ? {
        contentType: row.content_type,
        filename: row.filename ?? row.input_key.split("/").at(-1) ?? "source",
        inputKey: row.input_key,
        sizeBytes: row.size_bytes,
      }
    : null;
};
