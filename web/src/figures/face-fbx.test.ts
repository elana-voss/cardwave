import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Cache, type Mesh } from "three";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { Faces } from "./face";
import { loadFigure } from "./load";

// The committed FBX figure with face shapes (e2e/figures/faces.fbx, tools/test-figures.py): through three.js's FBX
// loader its shapes, in mixed case on two meshes, are matched to Cardwave's faces as a glTF's are.

beforeAll(() => {
  Cache.enabled = true;
  const bytes = readFileSync(join(process.cwd(), "..", "e2e", "figures", "faces.fbx"));
  Cache.add("file:faces.fbx", bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
});
afterAll(() => {
  Cache.clear();
  Cache.enabled = false;
});

describe("an FBX figure's face", () => {
  it("is matched to Cardwave's faces, each shape driven on every mesh that carries it", async () => {
    const model = await loadFigure("faces.fbx", "fbx");
    const faces = new Faces(model.root, null);
    for (const [face, weight] of [["open", 0.5], ["blink", 1], ["happy", 0.7], ["surprised", 0.3]] as const) faces.set(face, weight);
    const shaped: Record<string, Record<string, number>> = {};
    model.root.traverse((part) => {
      const { morphTargetDictionary: names, morphTargetInfluences: weights } = part as Mesh;
      if (names && weights) shaped[part.name] = Object.fromEntries(Object.entries(names).map(([name, at]) => [name, weights[at]!]));
    });
    expect(shaped).toEqual({
      Face: { JawOpen: 0.5, eyeblinkleft: 1, MOUTHSMILELEFT: 0.7 },
      Brows: { browInnerUp: 0.3, EyeBlinkLeft: 1 },
    });
    expect(faces.has("angry")).toBe(false);
  });
});
