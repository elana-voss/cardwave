import { describe, expect, it } from "vitest";
import { providersSaid } from "./settings";

const entry = (name: string, folder: string | null = null) => ({ id: 1, name, own_name: null, base_url: "", has_key: false, key_end: null, workflow: null, folder });

describe("the page Settings", () => {
  it("names the providers in Providers' grey line, this computer's as this computer", () => {
    expect(providersSaid([entry("OpenRouter"), entry("ComfyUI"), entry("This computer", "C:\Models")])).toBe("Set up: OpenRouter, ComfyUI, this computer");
    expect(providersSaid([])).toBe("Addresses and keys of the services that run the models");
  });
});
