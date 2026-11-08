// What the line "Dictation" and its dialog say of dictation's model in each of its states.
import { describe, expect, test, vi } from "vitest";
import type { DictationModel } from "../api/generated/DictationModel";
import { dialogSays, lineSays } from "./dictation-setup";

vi.mock("../api/client", () => ({}));

const model = (state: DictationModel["state"], done = 0): DictationModel => ({ name: "Whisper large-v3-turbo", size: 2_520_744_288, state, done, failure: null });

describe("dictation's model", () => {
  test("is set up from the line, downloaded, cancelled and removed from the dialog", () => {
    expect(lineSays(model("absent"))).toEqual({ says: "Not set up", action: "Set up" });
    expect(dialogSays(model("absent"))).toEqual({ state: "Not downloaded", action: "Download" });
    expect(lineSays(model("downloading", 1_260_372_144))).toEqual({ says: "Whisper large-v3-turbo · downloading 50%", action: "Change" });
    expect(dialogSays(model("downloading", 1_260_372_144))).toEqual({ state: "50%", action: "Cancel" });
    expect(lineSays(model("ready"))).toEqual({ says: "Whisper large-v3-turbo · This computer", action: "Change" });
    expect(dialogSays(model("ready"))).toEqual({ state: "Ready", action: "Remove" });
  });
});
