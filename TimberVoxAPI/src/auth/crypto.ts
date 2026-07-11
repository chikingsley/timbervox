const hexByte = (value: number): string => value.toString(16).padStart(2, "0");

export const sha256Hex = async (value: string): Promise<string> => {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map(hexByte).join("");
};

export const secretsEqual = async (
  provided: string,
  expected: string
): Promise<boolean> => {
  const encoder = new TextEncoder();
  const [providedHash, expectedHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  const providedBytes = new Uint8Array(providedHash);
  const expectedBytes = new Uint8Array(expectedHash);
  let difference = 0;
  for (let index = 0; index < providedBytes.length; index += 1) {
    // biome-ignore lint/suspicious/noBitwiseOperators: constant-time byte comparison requires bitwise aggregation.
    difference |= providedBytes[index] ^ expectedBytes[index];
  }
  return difference === 0;
};
