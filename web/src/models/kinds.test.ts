import { describe, expect, it, vi } from "vitest";
import { unpickKind } from "../api/client";
import type { ProvidersView } from "../api/generated/ProvidersView";
import { offeredFor, pickKind, providerName, says, type Catalogs } from "./kinds";

vi.mock("../api/client", async (real) => ({ ...(await real<object>()), unpickKind: vi.fn() }));

const model = (id: string, text: boolean, image: boolean) => ({ id, text, image, search: false, voice: false, thinks: false });
const models = [model("tide-1", true, false), model("paint-1", false, true), model("both-1", true, true)];

describe("the kinds of model", () => {
  it("offers a kind's models where the provider says their kinds, and all of them where it does not", () => {
    const said = { models, said: true, more: false, failed: null, workflows: null };
    expect(offeredFor("images", said).map((one) => one.id)).toEqual(["paint-1", "both-1"]);
    expect(offeredFor("background", said).map((one) => one.id)).toEqual(["tide-1", "both-1"]);
    expect(offeredFor("images", { ...said, said: false })).toEqual(models);
    const others = [{ ...model("embed-1", false, false), search: true }, { ...model("tts-1", false, false), voice: true }];
    const theirs = { ...said, models: [...models, ...others] };
    expect(offeredFor("search", theirs).map((one) => one.id)).toEqual(["embed-1"]);
    expect(offeredFor("voice", theirs).map((one) => one.id)).toEqual(["tts-1"]);
  });

  it("offers this computer's model first for Search, ticked until a provider's is taken, and taking it takes the kind back", async () => {
    const view: ProvidersView = {
      providers: [{ id: 4, name: "OpenAI", own_name: null, base_url: "https://api.openai.com/v1", has_key: true, key_end: "4f2a", workflow: null, folder: null }],
      kinds: [{ kind: "search", provider_id: 4, model: "embed-1", thinking: "on" }],
      own: [{ kind: "search", model: "bge-m3" }],
    };
    const lists: Catalogs = {
      of: () => ({ models: [{ ...model("embed-1", false, false), search: true }], said: true, more: false, failed: null, workflows: null }),
      ask: () => {},
      forget: () => {},
      listen: () => () => {},
    };
    vi.mocked(unpickKind).mockResolvedValue({ ...view, kinds: [] });
    let taken: ProvidersView | null = null;
    pickKind(document.body, "search", view, lists, (now) => (taken = now));
    const list = [...document.querySelectorAll(".kind-list")].at(-1)!;
    const options = () => [...list.querySelectorAll("[role=option]")].map((one) => [one.textContent, one.ariaSelected]);
    expect(options()).toEqual([["bge-m3 · on this computer", "false"], ["embed-1", "true"]]);
    (list.querySelector("[role=option]") as HTMLElement).click();
    list.closest("form")!.requestSubmit();
    await vi.waitFor(() => expect(taken).toEqual({ ...view, kinds: [] }));
    expect(unpickKind).toHaveBeenCalledWith("search");
  });

  it("says a kind's model with its provider, and nothing for a kind without one", () => {
    const view: ProvidersView = {
      providers: [{ id: 4, name: "OpenRouter", own_name: null, base_url: "https://openrouter.ai/api/v1", has_key: true, key_end: "4f2a", workflow: null, folder: null }],
      kinds: [{ kind: "chat", provider_id: 4, model: "tide-1", thinking: "on" }],
      own: [],
    };
    expect(says(view, "chat")).toBe("tide-1 · OpenRouter");
    expect(says(view, "chat", false)).toBe("tide-1");
    expect(says(view, "images")).toBeNull();
  });

  it("says why under a provider whose list came without the kind's models", () => {
    const view: ProvidersView = {
      providers: [{ id: 4, name: "OpenRouter", own_name: null, base_url: "https://openrouter.ai/api/v1", has_key: true, key_end: "4f2a", workflow: null, folder: null }],
      kinds: [],
      own: [],
    };
    const lists: Catalogs = {
      of: () => ({ models: [model("paint-1", false, true)], said: true, more: false, failed: { code: "models_not_listed", error: "the key was refused", details: {} }, workflows: null }),
      ask: () => {},
      forget: () => {},
      listen: () => () => {},
    };
    pickKind(document.body, "chat", view, lists, () => {});
    const list = document.querySelector(".kind-list")!;
    expect(list.textContent).toContain("The provider's models could not be listed.");
    expect([...list.querySelectorAll("button")].map((one) => one.textContent)).toEqual(["Try again"]);
    pickKind(document.body, "images", view, lists, () => {});
    expect([...document.querySelectorAll(".kind-list")].at(-1)!.querySelector("[role=option]")!.textContent).toBe("paint-1");
  });
});

describe("a provider's name", () => {
  it("is the short words for a program on this computer the program names not (the example only in first run's choice), else the provider's", () => {
    expect(providerName("")).toBe("A program on this computer");
    expect(providerName("Mine")).toBe("Mine");
  });
});
