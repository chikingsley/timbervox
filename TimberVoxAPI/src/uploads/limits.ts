export const SINGLE_PUT_THRESHOLD_BYTES = 100 * 1024 * 1024;
const MULTIPART_BASE_PART_BYTES = 16 * 1024 * 1024;
const R2_MAX_MULTIPART_PARTS = 10_000;

export const MEDIA_CONTENT_TYPES = new Set([
  "audio/flac",
  "audio/mp4",
  "audio/mpeg",
  "audio/ogg",
  "audio/wav",
  "audio/webm",
  "audio/x-m4a",
  "audio/x-wav",
  "video/mp4",
  "video/quicktime",
  "video/webm",
]);

export const normalizedContentType = (value: string): string =>
  value.split(";", 1)[0]?.trim().toLowerCase() ?? "";

export const multipartPartSize = (sizeBytes: number): number => {
  const minimumForPartLimit = Math.ceil(sizeBytes / R2_MAX_MULTIPART_PARTS);
  const mebibyte = 1024 * 1024;
  const roundedForPartLimit =
    Math.ceil(minimumForPartLimit / mebibyte) * mebibyte;
  return Math.max(MULTIPART_BASE_PART_BYTES, roundedForPartLimit);
};
