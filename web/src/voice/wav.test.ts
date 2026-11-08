// A recording written as the WAV file the server takes.
import { expect, test } from "vitest";
import { wav } from "./wav";

test("samples are written as a WAV file of 16-bit PCM, one channel, at their rate", async () => {
  const bytes = new DataView(await wav(new Float32Array([0.5, -1, 2]), 24_000).arrayBuffer());
  const text = (at: number) => String.fromCharCode(...new Uint8Array(bytes.buffer, at, 4));
  expect([text(0), text(8), text(12), text(36)]).toEqual(["RIFF", "WAVE", "fmt ", "data"]);
  expect([bytes.getUint16(22, true), bytes.getUint32(24, true), bytes.getUint16(34, true), bytes.getUint32(40, true)]).toEqual([1, 24_000, 16, 6]);
  // A sample beyond 1 is cut at 1.
  expect([bytes.getInt16(44, true), bytes.getInt16(46, true), bytes.getInt16(48, true)]).toEqual([16_384, -32_767, 32_767]);
});
