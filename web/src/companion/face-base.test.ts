import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Cache, type Mesh } from "three";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { loadFigure } from "../figures/load";
import { withoutPictures } from "../figures/shipped-files.test-support";
import { BLINK, LiveFace } from "./face";

// A base figure with a face (e2e/figures/faces-base.glb: tools/companion_assets.py's one-figure run on
// e2e/figures/faces.fbx), loaded as the companion loads the woman and the man, is driven by the faces alone.

beforeAll(() => {
  Cache.enabled = true;
  Cache.add("file:faces-base.glb", withoutPictures(readFileSync(join(process.cwd(), "..", "e2e", "figures", "faces-base.glb"))));
});
afterAll(() => {
  Cache.clear();
  Cache.enabled = false;
});

describe("a base figure with face shapes", () => {
  it("shows the feeling, shuts both shapes of the blink and opens the mouth with the voice", async () => {
    const model = await loadFigure("faces-base.glb", "glb");
    const live = new LiveFace(model.root, null, null, () => 0);
    live.show(BLINK.least, "happy", 0.6, false);
    live.show(BLINK.shut + BLINK.stay / 2, "happy", 0.6, false);
    const shaped: Record<string, number> = {};
    model.root.traverse((part) => {
      const { morphTargetDictionary: names, morphTargetInfluences: weights } = part as Mesh;
      if (names && weights) for (const [name, at] of Object.entries(names)) shaped[`${part.name}.${name}`] = weights[at]!;
    });
    expect(shaped).toMatchObject({ "Face.JawOpen": 0.6, "Face.MOUTHSMILELEFT": 1, "Brows.browInnerUp": 0 });
    expect([shaped["Face.eyeblinkleft"], shaped["Brows.EyeBlinkLeft"]]).toEqual([1, 1]);
  });
});
