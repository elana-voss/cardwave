import { describe, expect, it } from "vitest";
import type { FitModel } from "../api/generated/FitModel";
import { fitSays, memoryLine, onlySteps, usedFor } from "./fit-models";

const GB = 1024 ** 3;
const model = (change: Partial<FitModel>): FitModel => ({ file: "q.gguf", name: "Qwen3 4B", size: 2.5 * GB, fits: true, offered: true, state: "absent", done: 0, failure: null, ...change });
const own = { id: 7, name: "This computer", own_name: null, base_url: "", has_key: false, key_end: null, workflow: null, folder: "C:\\Models" };

describe("the models that fit this computer", () => {
  it("say their size and whether they fit, then how far they are", () => {
    expect(fitSays(model({}), [])).toBe("2.5 GB · Runs on this computer");
    expect(fitSays(model({ fits: false }), [])).toBe("2.5 GB · Too large for this computer");
    expect(fitSays(model({ state: "downloading", done: 1.05 * GB }), [])).toBe("2.5 GB · Runs on this computer · downloading 42%");
    expect(fitSays(model({ state: "downloaded" }), [])).toBe("2.5 GB · Runs on this computer · downloaded");
    expect(fitSays(model({ state: "downloaded" }), ["Chat", "Background"])).toBe("2.5 GB · Runs on this computer · used for Chat and Background");
    // A file of the user's own is there, not downloaded.
    expect(fitSays(model({ state: "downloaded", offered: false }), [])).toBe("2.5 GB · Runs on this computer");
  });

  it("tell the kinds at a model of This computer, and the memory beside the folder", () => {
    const kinds = [
      { kind: "chat" as const, provider_id: 7, model: "q.gguf", thinking: "on", gone: false },
      { kind: "background" as const, provider_id: 8, model: "q.gguf", thinking: "on", gone: false },
    ];
    expect(usedFor(kinds, own, "q.gguf")).toEqual(["Chat"]);
    expect(memoryLine(31.6 * GB, "C:\\Models")).toBe("32 GB of RAM · C:\\Models");
    expect(memoryLine(null, "C:\\Models")).toBe("C:\\Models");
  });

  it("tell a download's step from a change of the list, which redraws it", () => {
    const fit = (change: Partial<FitModel>) => ({ memory: 8 * GB, models: [model(change)] });
    expect(onlySteps(fit({ state: "downloading", done: 1 }), fit({ state: "downloading", done: 2 }))).toBe(true);
    expect(onlySteps(fit({ state: "downloading" }), fit({ state: "downloaded" }))).toBe(false);
    expect(onlySteps(fit({ state: "absent" }), fit({ state: "absent", failure: { code: "download_failed", error: "the download broke off", details: {} } }))).toBe(false);
  });
});
