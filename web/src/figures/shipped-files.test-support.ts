// Test support, imported by tests alone (vitest, node:fs): the shipped figures and clips (tools/companion_assets.py) and
// a user's own figure (e2e/figures, VRoid's names) for a test, which has no server: each file is handed to three.js through its cache (keyed `file:<url>`), its pictures dropped, as nothing in a test draws them (`withShippedFiles`, before a test file's tests).
// Trap: a VRM is read as one only while its extension stays named among those used.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Cache } from "three";
import { afterAll, beforeAll } from "vitest";
import carrier from "./animations.glb";
import woman from "./woman.glb";
import man from "./man.glb";

/** The GLB `bytes` without its pictures. */
export function withoutPictures(bytes: Buffer): ArrayBuffer {
  const length = bytes.readUInt32LE(12);
  const json = JSON.parse(bytes.subarray(20, 20 + length).toString("utf8")) as Record<string, unknown> & { materials?: unknown[] };
  for (const key of ["images", "textures", "samplers", "extensionsRequired"]) delete json[key];
  // A VRM is read as one only where its extension is named among those used (three-vrm).
  json.extensionsUsed = ((json.extensionsUsed as string[] | undefined) ?? []).filter((name) => !name.startsWith("KHR_texture"));
  if (json.materials) json.materials = json.materials.map(() => ({}));
  let text = JSON.stringify(json);
  text += " ".repeat((4 - (text.length % 4)) % 4);
  const head = Buffer.alloc(20);
  const rest = bytes.subarray(20 + length);
  head.writeUInt32LE(0x46546c67, 0);
  head.writeUInt32LE(2, 4);
  head.writeUInt32LE(20 + text.length + rest.length, 8);
  head.writeUInt32LE(text.length, 12);
  head.writeUInt32LE(0x4e4f534a, 16);
  const whole = Buffer.concat([head, Buffer.from(text, "utf8"), rest]);
  return whole.buffer.slice(whole.byteOffset, whole.byteOffset + whole.byteLength);
}

/** A file by its path from the folder `web`, where the tests run. */
const file = (...path: string[]) => readFileSync(join(process.cwd(), ...path));

/** Hands the files to three.js before the test file's tests and takes them back after. */
export function withShippedFiles(): void {
  beforeAll(() => {
    Cache.enabled = true;
    Cache.add(`file:${carrier}`, withoutPictures(file("src", "figures", "animations.glb")));
    Cache.add(`file:${woman}`, withoutPictures(file("src", "figures", "woman.glb")));
    Cache.add(`file:${man}`, withoutPictures(file("src", "figures", "man.glb")));
    Cache.add("file:own.vrm", withoutPictures(file("..", "e2e", "figures", "mannequin.vrm")));
  });
  afterAll(() => {
    Cache.clear();
    Cache.enabled = false;
  });
}
