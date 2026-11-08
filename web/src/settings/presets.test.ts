// What presets.ts decides without a browser: what a preset's line says under its name.
//
// `preset` is a preset with what the test names of it.
import { expect, test } from "vitest";
import type { PresetView } from "../api/generated/PresetView";
import { about } from "./presets";

const preset = (of: Partial<PresetView>): PresetView => ({ id: 1, name: "Reef", provider: "OpenRouter", model: "reef/tide-9", temperature: null, in_use: false, ...of });

test("a preset's line says whose API it asks and the model, and the temperature where one is set, zero too", () => {
  expect(about(preset({}))).toBe("OpenRouter · reef/tide-9");
  expect(about(preset({ temperature: 0.7 }))).toBe("OpenRouter · reef/tide-9 · temperature 0.7");
  expect(about(preset({ temperature: 0 }))).toBe("OpenRouter · reef/tide-9 · temperature 0");
  expect(about(preset({ provider: "127.0.0.1:5001", model: "attic-7b", temperature: 2 }))).toBe("127.0.0.1:5001 · attic-7b · temperature 2");
});
