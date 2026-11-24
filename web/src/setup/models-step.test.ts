// Whom first run's step 2 begins with (`storedFor`): the stored provider, else the one added last in Settings while
// no chat model is chosen, else none, and step 1 is shown. And the picks' races: a model chosen while the server's
// picks are on their way, and "Back" then "Continue" with the same key. Their Setup (`setup`) is of the step's own
// parts with the client stood in, the other steps and the model picker stand-ins: the picker takes the next ID of
// `chosen`, as the chat picker's choice or the helper picker's callback.
import { beforeEach, expect, test, vi } from "vitest";
import { pickModels, testModel } from "../api/client";
import type { EntryView } from "../api/generated/EntryView";
import type { NamedPicks } from "../api/generated/NamedPicks";
import type { ProviderView } from "../api/generated/ProviderView";
import { el, newest } from "../dom";
import { modelTest } from "../models/provider-form";
import { workClock } from "./models-state";
import { choose, giveUp, modelsParts, names, show, startStep, storedFor, tested, toModels, wire, type Setup } from "./models-step";

vi.mock("../api/client", () => ({
  pickModels: vi.fn(),
  testModel: vi.fn(),
  listModels: vi.fn(),
  getImages: vi.fn(() => new Promise(() => {})),
  listImageModels: vi.fn(),
  getSettings: vi.fn(() => new Promise(() => {})),
  listLanguages: vi.fn(() => new Promise(() => {})),
  changeSettings: vi.fn(),
  getProvider: vi.fn(),
  getProviderList: vi.fn(),
  setProvider: vi.fn(),
}));

const entry = (id: number, base_url: string, own_name: string | null = null): EntryView => ({ id, name: "x", own_name, base_url, has_key: true, key_end: "4f2a", workflow: null, folder: null });
const list = (providers: EntryView[]) => ({ providers, kinds: [], own: [] });

test("first run begins with the provider added last when no chat model is chosen, else the stored one, else none", () => {
  const added = list([entry(1, "https://one.test/v1"), entry(2, "https://two.test/v1", "Mine")]);
  expect(storedFor(null, added)).toEqual({ base_url: "https://two.test/v1", name: "Mine", has_key: true, key_end: "4f2a" });
  const stored = { base_url: "https://one.test/v1", model: "m", has_key: false, key_end: null, name: null, worker_model: null } as unknown as ProviderView;
  expect(storedFor(stored, added)).toBe(stored);
  expect(storedFor(null, list([]))).toBeNull();
  expect(storedFor(null, undefined)).toBeNull();
});

test("a provider that only makes the pictures is not the one first run begins with", () => {
  const added = { ...list([entry(1, "https://one.test/v1"), entry(2, "http://127.0.0.1:8188")]), kinds: [{ kind: "images" as const, provider_id: 2, model: "m", thinking: { control: "switch" as const, state: "off" }, gone: false }] };
  expect(storedFor(null, added)?.base_url).toBe("https://one.test/v1");
  expect(storedFor(null, { ...added, providers: [entry(2, "http://127.0.0.1:8188")] })).toBeNull();
});

test("a start before first run ended comes back to its downloads, else to the folder of cards it reached", () => {
  const at = (left: { downloads?: boolean; cards?: boolean; here?: boolean }) =>
    startStep({ provider: true, kept: true, downloads: false, cards: false, here: true, ...left });
  expect(at({})).toBe(2);
  expect(at({ cards: true })).toBe(3);
  expect(at({ cards: true, downloads: true })).toBe(4);
  expect(at({ cards: true, here: false })).toBe(2);
  expect(startStep({ provider: false, kept: true, downloads: false, cards: true, here: true })).toBe(2);
  expect(startStep({ provider: false, kept: false, downloads: false, cards: false, here: true })).toBe(1);
});

const NAMES = { "tide-1": "Tide 1", "reef/big-2": "Big 2", "reef/big-2-mini": "Big 2 Mini", "kelp/small-1": "Small 1" };
const asked = () => ({ base_url: "https://reef.test/v1", key: { api_key: "rk-test" } });

/** The picks the server answers with, held until `release`. */
function heldPicks(chat: string, background: string | null): () => void {
  let release = () => {};
  const held = new Promise<void>((done) => (release = done));
  vi.mocked(pickModels).mockImplementation(async () => {
    await held;
    return { names: NAMES, chat, background, images: null, listed: 3, failed: null } satisfies NamedPicks;
  });
  return release;
}

/** Step 2 with its own parts; the picker takes the IDs of `chosen` in turn. */
function setup(chosen: string[]): Setup {
  const node = el("section");
  document.body.replaceChildren(node);
  const box = () => el("div");
  const listing = {
    pick: (_current: string, _title?: string, then?: (id: string) => void) => (then ? then(chosen.shift()!) : choose(s, chosen.shift()!)),
    got: () => null,
  };
  const s: Setup = {
    ...modelsParts(() => node, () => s.asked!, { picking: () => s.picking, names: () => names(s) }),
    back: "#/",
    node,
    where: box(),
    title: box(),
    about: box(),
    first: { node: box(), key: el("input"), named: () => undefined } as unknown as Setup["first"],
    restoreLink: box(),
    restore: box(),
    restoring: false,
    cards: { node: box(), backButton: box(), go: box(), skip: box() } as unknown as Setup["cards"],
    choice: { node: box(), draw: () => {}, go: box(), back: box() } as unknown as Setup["choice"],
    third: { node: box() } as unknown as Setup["third"],
    downloading: false,
    notice: box(),
    attempt: async () => true,
    stored: null,
    local: false,
    step: 0,
    asked: null,
    picking: false,
    picks: newest(),
    picked: null,
    pickFailed: "",
    model: "",
    check: modelTest(() => show(s), tested()),
    worker: "",
    workerChosen: false,
    workerCheck: modelTest(() => show(s), tested()),
    listing: listing as unknown as Setup["listing"],
    clock: workClock(() => show(s), () => giveUp(s)),
  };
  node.append(s.second);
  wire(s);
  return s;
}

/** What a model's line says. */
const says = (line: { node: HTMLElement }) => line.node.querySelector(".item-text > .meta")!.textContent;
const settled = () => new Promise((done) => setTimeout(done));

beforeEach(() => {
  vi.mocked(pickModels).mockClear();
  vi.mocked(testModel).mockResolvedValue(undefined);
});

test("the picks asked before “Back” still count after “Continue” with the same key", async () => {
  const release = heldPicks("tide-1", null);
  const s = setup([]);
  toModels(s, asked());
  s.backButton.click();
  toModels(s, asked());
  expect(pickModels).toHaveBeenCalledTimes(1);
  release();
  await vi.waitFor(() => expect(says(s.chat)).toBe("Tide 1 · works"));
});

test("a chat model chosen while the picks are on their way stays, and is not also the helper", async () => {
  const release = heldPicks("reef/big-2", "kelp/small-1");
  const s = setup(["kelp/small-1"]);
  toModels(s, asked());
  s.chat.change.click();
  release();
  await vi.waitFor(() => expect(says(s.chat)).toBe("Small 1 · works"));
  await settled();
  expect(says(s.workerLine)).toBe("Same as the chat model");
});

test("a helper taken as the chat model while the picks are on their way stays so", async () => {
  const release = heldPicks("reef/big-2", "reef/big-2-mini");
  const s = setup(["kelp/small-1", "kelp/small-1"]);
  toModels(s, asked());
  s.chat.change.click();
  s.workerLine.change.click();
  release();
  await vi.waitFor(() => expect(says(s.chat)).toBe("Small 1 · works"));
  await settled();
  expect(says(s.workerLine)).toBe("Same as the chat model");
});

test("a helper chosen while the picks are on their way that the picks make the chat model is none", async () => {
  const release = heldPicks("reef/big-2", "kelp/small-1");
  const s = setup(["reef/big-2"]);
  toModels(s, asked());
  s.workerLine.change.click();
  release();
  await vi.waitFor(() => expect(says(s.chat)).toBe("Big 2 · works"));
  await settled();
  expect(says(s.workerLine)).toBe("Same as the chat model");
});
