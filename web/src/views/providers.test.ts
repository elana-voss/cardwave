import { describe, expect, it } from "vitest";
import type { ProvidersView } from "../api/generated/ProvidersView";
import type { ThinkingStep } from "../api/generated/ThinkingStep";
import { chatUnchosen, keyHint, thinkingShown, whereOf, workflowChoices, workflowNote } from "./providers";

const entry = (base_url: string, key_end: string | null, has_key: boolean) => ({ id: 1, name: "x", own_name: null, base_url, has_key, key_end, workflow: null, folder: null });

describe("the page Providers", () => {
  it("says where a provider is: the host, or the whole address of a server on this computer, and its key", () => {
    expect(whereOf(entry("https://openrouter.ai/api/v1", "4f2a", true))).toBe("openrouter.ai · key ····4f2a");
    expect(whereOf(entry("http://127.0.0.1:8080/v1", null, false))).toBe("http://127.0.0.1:8080/v1 · no key");
    expect(whereOf(entry("http://localhost:5001/v1", null, true))).toBe("http://localhost:5001/v1 · key saved");
  });

  it("says under the key of an edited provider that another address needs the key typed again", () => {
    const own = entry("https://a.example/v1", "4f2a", true);
    expect(keyHint(own, "https://a.example/v1/")).toBe("Leave empty to keep the saved key.");
    expect(keyHint(own, "https://b.example/v1")).toBe("A new address needs its key typed again: a key never goes to another server.");
    expect(keyHint(entry("https://a.example/v1", null, false), "https://b.example/v1")).toBe("Leave empty to keep the saved key.");
  });

  it("has a line Thinking with the switch under a model without levels that thinks, or whose thinking was turned off", () => {
    const shown = (state: string, thinker: boolean) => thinkingShown({ control: "switch", state }, thinker, "OpenRouter");
    expect(shown("on", true)).toEqual({ says: "The model thinks before it replies", control: "switch", on: true });
    expect(shown("on", false)).toBeNull();
    expect(shown("off", false)).toEqual({ says: "The model replies without thinking first", control: "switch", on: false });
    expect(shown("cannot", true)).toEqual({ says: "OpenRouter can't turn thinking off for this model", control: "none" });
  });

  it("has the field of the steps a model offers in the line Thinking, without Off where it cannot stop thinking", () => {
    const all: ThinkingStep[] = ["off", "light", "normal", "deep"];
    const shown = (steps: ThinkingStep[], step: ThinkingStep, refused = false) => thinkingShown({ control: "steps", steps, step, refused }, false, "OpenAI");
    const labels = (steps: ThinkingStep[]) => {
      const now = shown(steps, steps[0]);
      return now?.control === "steps" ? now.choices.map(({ value, label }) => `${value}:${label}`) : now;
    };
    expect(labels(all)).toEqual(["off:Off", "light:Light", "normal:Normal", "deep:Deep"]);
    expect(labels(["light", "normal", "deep"])).toEqual(["light:Light", "normal:Normal", "deep:Deep"]);
    expect(shown(all, "deep")).toMatchObject({ says: "How much the model thinks before it replies", control: "steps", step: "deep" });
    expect(shown(all, "off")).toMatchObject({ says: "The model replies without thinking first", step: "off" });
    // Off refused by the provider: Off is no longer offered, the model is at the step it falls back to, and the line says why.
    expect(shown(["light", "normal", "deep"], "normal", true)).toMatchObject({ says: "OpenAI can't turn thinking off for this model", step: "normal" });
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

  it("sends on to first run's models after a provider is added while no chat model is chosen", () => {
    const view = (kinds: string[]) => ({ providers: [], kinds: kinds.map((kind) => ({ kind, provider_id: 1, model: "m", thinking: { control: "switch" as const, state: "on" }, gone: false })), own: [] }) as unknown as ProvidersView;
    expect(chatUnchosen(view(["images"]))).toBe(true);
    expect(chatUnchosen(view(["chat", "images"]))).toBe(false);
  });
});
