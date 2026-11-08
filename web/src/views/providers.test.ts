import { describe, expect, it } from "vitest";
import { thinkingSays, whereOf, workflowChoices, workflowNote } from "./providers";

const entry = (base_url: string, key_end: string | null, has_key: boolean) => ({ id: 1, name: "x", own_name: null, base_url, has_key, key_end, workflow: null, folder: null });

describe("the page Providers", () => {
  it("says where a provider is: the host, or the whole address of a server on this computer, and its key", () => {
    expect(whereOf(entry("https://openrouter.ai/api/v1", "4f2a", true))).toBe("openrouter.ai · key ····4f2a");
    expect(whereOf(entry("http://127.0.0.1:8080/v1", null, false))).toBe("http://127.0.0.1:8080/v1 · no key");
    expect(whereOf(entry("http://localhost:5001/v1", null, true))).toBe("http://localhost:5001/v1 · key saved");
  });

  it("has a line Thinking under a model that thinks, or whose thinking was turned off", () => {
    const picked = (thinking: string) => ({ kind: "chat" as const, provider_id: 1, model: "m", thinking });
    expect(thinkingSays(picked("on"), true, "OpenRouter")).toBe("The model thinks before it replies");
    expect(thinkingSays(picked("on"), false, "OpenRouter")).toBeNull();
    expect(thinkingSays(picked("off"), false, "OpenRouter")).toBe("The model replies without thinking first");
    expect(thinkingSays(picked("cannot"), true, "OpenRouter")).toBe("OpenRouter can't turn thinking off for this model");
  });

  it("offers a ComfyUI's default workflow and its saved ones, and keeps the one picked that ComfyUI no longer holds", () => {
    const labels = (names: string[], picked: string | null) => workflowChoices(names, picked).map((each) => [each.value, each.label]);
    expect(labels(["flux.json", "sub/sdxl.JSON"], null)).toEqual([["", "ComfyUI's default"], ["flux.json", "flux"], ["sub/sdxl.JSON", "sub/sdxl"]]);
    expect(labels(["flux.json"], "gone.json")).toEqual([["", "ComfyUI's default"], ["flux.json", "flux"], ["gone.json", "gone"]]);
  });

  it("says under a saved workflow that it uses its own models and size, and nothing under the default", () => {
    expect(workflowNote("flux.json")).toBe("This workflow uses its own models and size, not the Images model.");
    expect(workflowNote(null)).toBeNull();
  });
});
