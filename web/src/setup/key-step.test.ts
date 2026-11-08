// What first run's first step decides, without a browser: whose key a key is (`recognise`), which of its
// states the step shows for a key, whom it hands on (`Asked`), what "Find by name" looks up where, and which
// servers on this computer it offers. The server is a stand-in (`../api/client`): the list of providers is
// `LIST`, and a test says what a search or an asking for models answers.
import { beforeEach, expect, test, vi } from "vitest";
import { findProvider, getProviders, listModels } from "../api/client";
import type { KnownProvider } from "../api/generated/KnownProvider";
import type { ProviderView } from "../api/generated/ProviderView";
import { setElsewhere } from "../account";
import { keyStep, recognise, type Asked, type KeyStep } from "./key-step";

vi.mock("../api/client", () => ({ findProvider: vi.fn(), getProviders: vi.fn(), listModels: vi.fn() }));

const of = (name: string, base_url: string, keys: string[] = [], local = false): KnownProvider => ({ name, base_url, keys, local });
const LIST = [
  of("DeepSeek", "https://api.deepseek.com/v1", ["sk-"]),
  of("KoboldCpp", "http://127.0.0.1:5001/v1", [], true),
  of("Ollama", "http://127.0.0.1:11434/v1", [], true),
  of("OpenAI", "https://api.openai.com/v1", ["sk-proj-", "sk-"]),
  of("OpenRouter", "https://openrouter.ai/api/v1", ["sk-or-v1-"]),
  of("Reef", "https://api.reef.test/v1"),
  of("Reef North", "https://north.reef.test/v1"),
  of("Together AI", "https://api.together.xyz/v1"),
  ...["One", "Two", "Three", "Four", "Five", "Six"].map((n) => of(`Tide ${n}`, `https://${n.toLowerCase()}.tide.test/v1`)),
];
const names = (found: KnownProvider[]) => found.map((provider) => provider.name);

test("a key is the provider's whose keys begin as it does, and of several beginnings the longest counts", () => {
  expect(names(recognise("sk-or-v1-0123456789abcdef", LIST))).toEqual(["OpenRouter"]);
  // In whatever order the list has them.
  expect(names(recognise("sk-or-v1-0123456789abcdef", [...LIST].reverse()))).toEqual(["OpenRouter"]);
  expect(names(recognise("sk-proj-0123456789abcdef", LIST))).toEqual(["OpenAI"]);
  // A beginning two providers share is both's, each once.
  expect(names(recognise("sk-0123456789abcdef", LIST))).toEqual(["DeepSeek", "OpenAI"]);
  // No provider's keys begin so, and a beginning alone is no key.
  expect(recognise("0123456789abcdef", LIST)).toEqual([]);
  expect(recognise("xsk-or-v1-0123456789", LIST)).toEqual([]);
  expect(names(recognise("sk-or-v1-", LIST))).toEqual(["DeepSeek", "OpenAI"]);
  expect(recognise("sk-", LIST)).toEqual([]);
  expect(recognise("", LIST)).toEqual([]);
});

let went: Asked[] = [];
/** The way elsewhere that stands beside Continue (first run's "Enter the provider's address in Settings"). */
const elsewhere = document.createElement("button");
let step: KeyStep;

/** How many times the step said that the list of providers had come. */
let listed = 0;

/** Makes the step and waits for the list of providers. */
async function make(stored: ProviderView | null = null): Promise<void> {
  step = keyStep(
    (asked) => went.push(asked),
    () => listed++,
    undefined,
    elsewhere,
  );
  document.body.replaceChildren(step.node);
  step.node.hidden = false;
  step.fill(stored);
  await vi.waitFor(() => expect(getProviders).toHaveBeenCalled());
  await new Promise((done) => setTimeout(done));
}

beforeEach(() => {
  went = [];
  vi.mocked(getProviders).mockReset().mockResolvedValue(LIST);
  vi.mocked(findProvider).mockReset().mockResolvedValue(null);
  vi.mocked(listModels).mockReset().mockRejectedValue(new Error("nothing listens"));
});

const part = (selector: string) => step.node.querySelector<HTMLElement>(selector)!;
const shows = (selector: string) => !part(selector).hidden && !part(selector).closest("[hidden]");
const button = (name: string) => [...step.node.querySelectorAll("button")].find((one) => one.textContent === name && !one.closest("[hidden]"))!;
const field = (name: string) => step.node.querySelector<HTMLInputElement>(`input[name="${name}"]`)!;
/** Types into a field, as a user does. */
function type(input: HTMLInputElement, text: string): void {
  input.value = text;
  input.dispatchEvent(new Event("input", { bubbles: true }));
}
const key = (text: string) => type(step.key, text);
const submit = () => step.node.dispatchEvent(new Event("submit", { cancelable: true }));
/** The lines of what was found: what each is called and its address. */
const lines = (within: string) => [...part(within).querySelectorAll(".item")].map((line) => [line.querySelector(".item-label")!.textContent, line.querySelector(".meta")!.textContent]);
/** Which parts under the key show: the provider recognised, the choice of several, and what is set by hand. */
const state = () => ({ recognised: shows(".recognised"), several: shows(".several"), byHand: shows(".by-hand"), unknown: shows(".unknown"), noKey: shows(".no-key") });
const NOTHING = { recognised: false, several: false, byHand: false, unknown: false, noKey: true };

test("without a key the step says nothing of one and cannot go on, but for a server on this computer", async () => {
  await make();
  expect(state()).toEqual(NOTHING);
  expect(button("Continue").disabled).toBe(true);
  // The empty field says what is missing; the way elsewhere stands beside Continue; what a server on this
  // computer answers comes under its line, before Continue.
  expect([step.key.placeholder, elsewhere.parentElement, elsewhere.hidden]).toEqual(["Paste your key here", button("Continue").parentElement, false]);
  expect(part(".servers").compareDocumentPosition(button("Continue")) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  submit();
  expect(went).toEqual([]);
});

test("a key that is recognised names its provider, and Continue goes on with that provider's address and the key", async () => {
  await make();
  key("  sk-or-v1-0123456789abcdef ");
  expect(state()).toEqual({ ...NOTHING, recognised: true });
  expect(part(".recognised b").textContent).toBe("OpenRouter");
  expect(button("Continue").disabled).toBe(false);
  submit();
  expect(went).toEqual([{ base_url: "https://openrouter.ai/api/v1", key: { api_key: "sk-or-v1-0123456789abcdef" } }]);
});

test("a key that several providers' keys begin as has the user choose between them before it goes on", async () => {
  await make();
  key("sk-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, several: true });
  const pills = () => [...part(".several .pills").querySelectorAll("button")];
  expect(pills().map((pill) => [pill.textContent, pill.ariaPressed])).toEqual([
    ["DeepSeek", "false"],
    ["OpenAI", "false"],
  ]);
  // Not before one is chosen.
  expect(button("Continue").disabled).toBe(true);
  submit();
  expect(went).toEqual([]);
  pills()[1].click();
  expect(pills().map((pill) => pill.ariaPressed)).toEqual(["false", "true"]);
  expect(button("Continue").disabled).toBe(false);
  submit();
  expect(went).toEqual([{ base_url: "https://api.openai.com/v1", key: { api_key: "sk-0123456789abcdef" } }]);
  // Another key is another choice: the one made is not kept for a key that is one provider's.
  key("sk-or-v1-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, recognised: true });
  key("sk-0123456789abcdefg");
  expect(pills().map((pill) => pill.ariaPressed)).toEqual(["false", "false"]);
  expect(button("Continue").disabled).toBe(true);
});

test("a key that is not recognised has the provider set by hand, and so has one the user says is another's, until another key is typed", async () => {
  await make();
  key("0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, byHand: true, unknown: true, noKey: false });
  // "Find by name" first, which goes on by what it finds: Continue stays, greyed, Enter in the key's field goes
  // nowhere, and the way elsewhere is not there beside the switch's "Enter address".
  expect([shows('input[name="find"]'), shows('input[name="base_url"]'), button("Continue").disabled, elsewhere.hidden]).toEqual([true, false, true, true]);
  submit();
  expect(went).toEqual([]);

  key("sk-or-v1-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, recognised: true });
  button("Not this one?").click();
  // It was recognised, so it is not said that it was not.
  expect(state()).toEqual({ ...NOTHING, byHand: true, noKey: false });
  expect(document.activeElement).toBe(field("find"));
  // The key mended is that provider's still, which the user said it is not: it stays set by hand.
  key("sk-or-v1-0123456789abcdefg");
  expect(state()).toEqual({ ...NOTHING, byHand: true, noKey: false });
  // Another provider's key is judged anew, and after it the first one's too.
  key("sk-proj-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, recognised: true });
  key("sk-or-v1-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, recognised: true });

  key("sk-0123456789abcdef");
  button("None of these?").click();
  expect(state()).toEqual({ ...NOTHING, byHand: true, noKey: false });
  // Mended, it is none of the several still; a key of one of them alone is judged anew.
  key("sk-0123456789abcdefg");
  expect(state()).toEqual({ ...NOTHING, byHand: true, noKey: false });
  key("sk-proj-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, recognised: true });
  key("sk-0123456789abcdef");
  button("None of these?").click();

  // The key taken out of the field leaves what is set by hand: its address may need no key. The way to a server on
  // this computer is there again.
  button("Enter address").click();
  type(field("base_url"), "https://rig.example.test/v1");
  key("");
  expect(state()).toEqual({ ...NOTHING, byHand: true });
  expect([shows('input[name="base_url"]'), field("base_url").value]).toEqual([true, "https://rig.example.test/v1"]);
  submit();
  expect(went).toEqual([{ base_url: "https://rig.example.test/v1", key: {}, name: "" }]);
});

test("a provider's own name has sixty signs at most, counted as the server counts them", async () => {
  await make();
  key("0123456789abcdef");
  button("Enter address").click();
  // A sign that takes two units of a text is one sign.
  type(field("name"), "\u{1F30A}".repeat(61));
  expect(field("name").value).toBe("\u{1F30A}".repeat(60));
  type(field("name"), "n".repeat(61));
  expect(field("name").value).toBe("n".repeat(60));
});

test("Enter address takes the provider's own name and its address, and goes on with them and the key", async () => {
  await make();
  key("0123456789abcdef");
  button("Enter address").click();
  expect([shows('input[name="find"]'), shows('input[name="base_url"]')]).toEqual([false, true]);
  // The address, which is needed, comes first and has the focus; the optional name under it.
  expect(document.activeElement).toBe(field("base_url"));
  expect(field("base_url").compareDocumentPosition(field("name")) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  // The address is asked for only while its field shows.
  expect(field("base_url").required).toBe(true);
  type(field("name"), "  My rig ");
  type(field("base_url"), " https://rig.example.test/v1/ ");
  submit();
  expect(went).toEqual([{ base_url: "https://rig.example.test/v1", key: { api_key: "0123456789abcdef" }, name: "My rig" }]);
  button("Find by name").click();
  expect([shows('input[name="find"]'), shows('input[name="base_url"]'), field("base_url").required]).toEqual([true, false, false]);
});

test("Find by name looks a name up in the list, whole before in part, and offers each address with the key", async () => {
  await make();
  key("0123456789abcdef");
  const look = (wanted: string) => {
    type(field("find"), wanted);
    button("Find").click();
  };
  // The whole name, whatever its case, is that provider alone, though another has it in its own.
  look("  openai ");
  expect(lines(".found-list")).toEqual([["OpenAI", "https://api.openai.com/v1"]]);
  look("REEF");
  expect(lines(".found-list")).toEqual([["Reef", "https://api.reef.test/v1"]]);
  look("reef n");
  expect(lines(".found-list")).toEqual([["Reef North", "https://north.reef.test/v1"]]);
  // A part of a name is all that have it, five at most.
  look("tide");
  expect(lines(".found-list").map(([name]) => name)).toEqual(["Tide One", "Tide Two", "Tide Three", "Tide Four", "Tide Five"]);
  look("together");
  expect(lines(".found-list")).toEqual([["Together AI", "https://api.together.xyz/v1"]]);
  // The list was enough: the server was asked nothing.
  expect(findProvider).not.toHaveBeenCalled();
  part(".found-list button").click();
  expect(went).toEqual([{ base_url: "https://api.together.xyz/v1", key: { api_key: "0123456789abcdef" } }]);
});

test("what is no name of the list is looked for as a website by the server, and a word that is neither says so and leads to Enter address", async () => {
  await make();
  key("0123456789abcdef");
  const find = field("find");
  // Enter in the field looks, and does not go on.
  const enter = () => find.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }));
  vi.mocked(findProvider).mockResolvedValue({ base_url: "https://api.harbour.test/v1", name: null });
  type(find, " harbour.test ");
  enter();
  await vi.waitFor(() => expect(lines(".found-list")).toEqual([["Found", "https://api.harbour.test/v1"]]));
  expect(vi.mocked(findProvider).mock.calls).toEqual([[{ website: "harbour.test" }]]);
  // What the server knows by name is called so.
  vi.mocked(findProvider).mockResolvedValue({ base_url: "https://api.quay.test/v1", name: "Quay" });
  type(find, "quay.test");
  enter();
  await vi.waitFor(() => expect(lines(".found-list")).toEqual([["Quay", "https://api.quay.test/v1"]]));
  expect(went).toEqual([]);

  // Nothing found says so, with the way to enter the address.
  vi.mocked(findProvider).mockResolvedValue(null);
  type(find, "nowhere.test");
  enter();
  await vi.waitFor(() => expect(part(".found-list").textContent).toContain("Cardwave found no address for the AI on nowhere.test."));
  // A word without a dot is no website: the server is not asked.
  const asked = vi.mocked(findProvider).mock.calls.length;
  type(find, "harbourmaster");
  enter();
  expect(part(".found-list").textContent).toContain("No provider called “harbourmaster” is on the list.");
  expect(vi.mocked(findProvider).mock.calls.length).toBe(asked);
  part(".found-list button").click();
  expect([shows('input[name="base_url"]'), document.activeElement]).toEqual([true, field("base_url")]);
  // An empty field looks for nothing.
  button("Find by name").click();
  type(find, "  ");
  enter();
  expect(vi.mocked(findProvider).mock.calls.length).toBe(asked);
});

test("the servers on this computer that answer are offered, and one taken goes on without a key", async () => {
  await make();
  // A key in the field is another provider's.
  key("sk-or-v1-0123456789abcdef");
  vi.mocked(listModels).mockImplementation(({ base_url }) => (base_url.includes(":11434") ? Promise.resolve({ models: [], more: false }) : Promise.reject(new Error("nothing listens"))));
  expect(shows(".servers")).toBe(false);
  button("Use a program on this computer (such as LM Studio or Ollama)").click();
  expect(part(".servers").textContent).toBe("Looking for programs on this computer…");
  await vi.waitFor(() => expect(lines(".servers")).toEqual([["Ollama", "http://127.0.0.1:11434/v1"]]));
  // Each server of the list that is on this computer was asked, without a key, and no other.
  expect(vi.mocked(listModels).mock.calls.map(([asked]) => asked)).toEqual([
    { base_url: "http://127.0.0.1:5001/v1", api_key: "" },
    { base_url: "http://127.0.0.1:11434/v1", api_key: "" },
  ]);
  // Under them the way to a server that is not on the list.
  expect([...part(".servers").querySelectorAll("button")].map((one) => one.textContent)).toEqual(["Use this", "Enter address"]);
  part(".servers button").click();
  expect(went).toEqual([{ base_url: "http://127.0.0.1:11434/v1", key: { api_key: "" } }]);

  // Where none answers the step says so, and leads to Enter address.
  vi.mocked(listModels).mockRejectedValue(new Error("nothing listens"));
  button("Use a program on this computer (such as LM Studio or Ollama)").click();
  await vi.waitFor(() => expect(part(".servers").textContent).toContain("No AI program answers on this computer (Cardwave looked for KoboldCpp, Ollama). Start one, then look again."));
  part(".servers button").click();
  expect(state()).toEqual({ ...NOTHING, byHand: true, noKey: false });
  expect(shows('input[name="base_url"]')).toBe(true);
  // The servers were not it: their list is gone, also where the way to them shows again, without a key.
  key("");
  expect([shows(".no-key"), shows(".servers")]).toEqual([true, false]);
});

test("gone through again, the step begins with what is saved: its address and name to enter, and the key's end in the field", async () => {
  const stored: ProviderView = { base_url: "https://rig.example.test/v1", model: "tide-1", has_key: true, key_end: "4f2a", sampling: {}, name: "My rig" } as ProviderView;
  await make(stored);
  expect(state()).toEqual({ ...NOTHING, byHand: true });
  expect([step.key.value, step.key.placeholder, field("name").value, field("base_url").value]).toEqual(["", "····4f2a is saved", "My rig", "https://rig.example.test/v1"]);
  // Continue without a key leaves the key out, so the stored one stays.
  submit();
  expect(went).toEqual([{ base_url: "https://rig.example.test/v1", key: {}, name: "My rig" }]);
  // A key typed is judged as any: one that is a provider's goes there.
  key("sk-or-v1-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, recognised: true });
  // One that is not has the stored address to go on with.
  key("0123456789abcdef");
  expect([shows('input[name="base_url"]'), field("base_url").value]).toEqual([true, "https://rig.example.test/v1"]);
  // A provider the user set aside before is not set aside when the step begins anew: its key is judged as any.
  key("sk-or-v1-0123456789abcdef");
  button("Not this one?").click();
  step.fill(stored);
  key("sk-or-v1-0123456789abcdefg");
  expect(state()).toEqual({ ...NOTHING, recognised: true });

  // A short key's end is not told, and without a key the field says nothing.
  step.fill({ ...stored, key_end: null });
  expect(step.key.placeholder).toBe("A key is saved");
  step.fill(null);
  expect([step.key.placeholder, field("base_url").value, field("name").value]).toEqual(["Paste your key here", "", ""]);
  expect(state()).toEqual(NOTHING);
});

test("the list's name for an address is told, and without the list no key is recognised", async () => {
  listed = 0;
  await make();
  // Who made the step is told that the list has come, as an address has its name from then on.
  expect(listed).toBe(1);
  expect(step.named("https://openrouter.ai/api/v1")).toBe("OpenRouter");
  // This computer by its name is the list's address by its number.
  expect(step.named("http://localhost:5001/v1/")).toBe("KoboldCpp");
  expect(step.named("https://rig.example.test/v1")).toBeUndefined();

  vi.mocked(getProviders).mockReset().mockRejectedValue(new Error("the list is away"));
  await make();
  expect(step.node.querySelector('[role="alert"]')!.textContent).toContain("The list is away");
  key("sk-or-v1-0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, byHand: true, unknown: true, noKey: false });
});

test("until the list of providers has come nothing is said of a key", async () => {
  let come = (_: KnownProvider[]) => {};
  vi.mocked(getProviders).mockReset().mockReturnValue(new Promise((done) => (come = done)));
  step = keyStep((asked) => went.push(asked));
  document.body.replaceChildren(step.node);
  step.node.hidden = false;
  key("0123456789abcdef");
  expect(state()).toEqual({ ...NOTHING, noKey: false });
  expect(button("Continue").disabled).toBe(true);
  come(LIST);
  await vi.waitFor(() => expect(state()).toEqual({ ...NOTHING, byHand: true, unknown: true, noKey: false }));
});

test("on another device the programs are those of the computer Cardwave runs on", async () => {
  setElsewhere(true);
  await make();
  button("Use a program on the computer Cardwave runs on (such as LM Studio or Ollama)").click();
  expect(part(".servers").textContent).toBe("Looking for programs on the computer Cardwave runs on…");
  await vi.waitFor(() => expect(part(".servers").textContent).toContain("No AI program answers on the computer Cardwave runs on (Cardwave looked for KoboldCpp, Ollama). Start one there, then look again."));
  setElsewhere(false);
});
