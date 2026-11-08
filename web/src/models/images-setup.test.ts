// What the line "Images" says of the image model.
import { expect, test } from "vitest";
import { imageSays } from "./images-setup";

test("the line says the image model, and the host of an address of its own", () => {
  expect(imageSays(null)).toEqual({ says: "Pictures of your characters · not set up", action: "Set up" });
  // While first run picks, the line shows the spinner alone, its button already "Change".
  expect(imageSays(null, true).action).toBe("Change");
  expect(imageSays({ model: "gpt-image-1", base_url: null, has_key: false, key_end: null })).toEqual({ says: "gpt-image-1", action: "Change" });
  const comfy = { model: "sdxl.safetensors", base_url: "http://127.0.0.1:8188", has_key: false, key_end: null };
  expect(imageSays(comfy)).toEqual({ says: "sdxl.safetensors · 127.0.0.1:8188", action: "Change" });
});
