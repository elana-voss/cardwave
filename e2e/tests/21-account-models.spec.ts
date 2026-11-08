import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// The account's group "Models": a line to Settings › Providers, then Chat and Images, and Settings › Advanced's
// "Helper model" with Helper, each its model and provider with "Change", which opens the model picker of that kind (the models of every provider, grouped
// under the provider's name), stores the model taken at once and tests it. The test stores the provider it
// starts from itself (`store`), at the stand-ins `api` and `other`; no test asks a provider. A stand-in does not
// say what kind its models are, so its heading says "· not known whether it can do this" and all its models are listed.

let api: FakeProvider;
/** Another address, with models of its own. */
let other: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
  other = await startFakeProvider();
  other.models(["duo", "solo"]);
});
test.afterAll(() => Promise.all([api.close(), other.close()]));

/** A key long enough for its end to be told. */
const KEY = "sk-account-0123456789-7c1d";
const QUESTION = "Reply with the single word OK.";

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
/** The group "Models", the chat model's line in it (or the line called `name`), and what the line says under its name. */
const group = (page: Page) => page.locator(".settings-group", { has: page.getByRole("heading", { name: "Models", exact: true }) });
const line = (page: Page, name = "Chat") => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) });
const says = (page: Page, name = "Chat") => line(page, name).locator(".item-text > .meta");
const change = (page: Page, what = "chat") => button(page, `Change the ${what} model`);
/** The model picker called `title`, its search field, and the lines of its list. */
const picker = (page: Page, title = "Chat model") => page.getByRole("dialog", { name: title });
const search = (page: Page, title?: string) => picker(page, title).getByLabel("Model", { exact: true });
/** The picker's lines: a provider's model by its ID (grey under its readable name), this computer's by its words. */
const offered = (page: Page, title?: string) =>
  picker(page, title).getByRole("option").evaluateAll((lines) => lines.map((line) => line.querySelector(".opt-id")?.textContent ?? line.textContent));
const use = (page: Page) => button(page, "Use this model");
const rest = (page: Page) => page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));
const host = (at: FakeProvider) => new URL(at.url).host;
/** What a provider on this computer the user did not name is called. */
const HERE = "A program on this computer";

/** Stores a provider at `at`, with a key and values for a reply, and without a worker model. */
async function store(request: APIRequestContext, at: FakeProvider = api, name = "tide-1"): Promise<void> {
  const stored = await request.put("/api/provider", { data: { base_url: at.url, model: name, api_key: KEY, sampling: { temperature: 0.7, seed: 7 }, worker_model: "" } });
  expect(stored.status(), await stored.text()).toBe(200);
}

const stored = async (request: APIRequestContext) => (await request.get("/api/provider")).json();

/** Opens the settings (or Settings › Advanced), from an empty page, so that the app starts anew also where the test had it open. */
async function open(page: Page, advanced = false): Promise<void> {
  await page.goto("about:blank");
  await page.goto(advanced ? "/#/settings/advanced" : "/#/settings");
  await expect(advanced ? line(page, "Helper model") : group(page)).toBeVisible();
}

test("the settings begin with the chat model that is stored, and “Change” stores the model picked there and tests it", async ({ page, request }) => {
  api.models(["tide-2", "Reef-1", "tide-1"]);
  await store(request);
  const [listed, asked] = [api.listed.length, api.asked.length];
  await open(page);

  // The group stands under "Appearance": the link to Providers, the chat model's line, the image model's, the
  // voice's (spec 48) and the search model's (spec 40). What is seldom changed is on Settings › Advanced, which
  // the last box names, each setting in one place only.
  await expect(page.locator(".settings-group h2")).toHaveText(["Appearance", "Language", "Models", "Tools", "Data"]);
  await expect(group(page).locator(".item-label")).toHaveText(["Providers", "Chat", "Images", "Voice", "Search", "Dictation"]);
  await expect(page.locator(".settings-group").last().locator(".item-label").first()).toHaveText("Advanced");
  await page.getByRole("link", { name: /^Advanced/ }).click();
  await expect(page.locator(".settings-group h2")).toHaveText(["Helper model", "Chat without a character", "Library", "Data", "Model presets", "Prompt presets"]);
  await expect(line(page, "Helper model")).toBeVisible();
  await page.goBack();
  await expect(says(page)).toHaveText(`tide-1 · ${HERE}`);
  await expect(says(page, "Images")).toHaveText("Not set up");
  await expect(change(page)).toBeEnabled();
  // Opening the settings asks the provider nothing: not for its models, and the model no question.
  await rest(page);
  expect([api.listed.length, api.asked.length]).toEqual([listed, asked]);

  // "Change" opens the picker of the kind, with the search focused, and asks each provider for its models, with its key.
  await change(page).click();
  await expect(search(page)).toBeFocused();
  await expect(picker(page).locator(".kind-group")).toHaveText([`${HERE} · ${host(api)} · not known whether it can do this`]);
  await expect.poll(() => offered(page)).toEqual(["Reef-1", "tide-1", "tide-2"]);
  expect(api.listed.slice(listed)).toContainEqual({ path: "/v1/models", key: `Bearer ${KEY}` });
  await expect(picker(page).getByRole("option", { name: "tide-1" })).toHaveAttribute("aria-selected", "true");
  // What is typed narrows the list; a line taken, "Use this model" stores it at once and tests it.
  await search(page).fill("reef");
  expect(await offered(page)).toEqual(["Reef-1"]);
  await picker(page).getByRole("option", { name: "Reef-1" }).click();
  await use(page).click();
  await expect(page.locator("dialog")).toHaveCount(0);
  await expect(says(page)).toHaveText(`Reef-1 · ${HERE} · test passed`);
  expect((await stored(request)).model).toBe("Reef-1");
  expect(api.asked.slice(asked)).toEqual([{ key: `Bearer ${KEY}`, body: { model: "Reef-1", messages: [{ role: "user", content: QUESTION }], stream: true } }]);

  // Left by "Cancel" or Escape, the picker stores nothing and asks nothing.
  await change(page).click();
  await picker(page).getByRole("option", { name: "tide-2" }).click();
  await button(page, "Cancel").click();
  await change(page).click();
  await page.keyboard.press("Escape");
  await expect(page.locator("dialog")).toHaveCount(0);
  expect((await stored(request)).model).toBe("Reef-1");
  expect(api.asked.length).toBe(asked + 1);

  // Opened anew, the settings show the stored model, and what its test came to is not kept.
  await open(page);
  await expect(says(page)).toHaveText(`Reef-1 · ${HERE}`);

  // A reply the provider refused as it no longer offers the model: the line says so, kept by the server, so
  // the page still asks nothing on open; the model picked anew ends it.
  const made = await request.post("/api/chats", { data: { characters: [] } });
  expect(made.status(), await made.text()).toBe(201);
  const chat = (await made.json()).chat.id;
  expect((await request.post(`/api/chats/${chat}/messages`, { data: { content: "Hello?" } })).status()).toBe(201);
  api.fail(404, "The model `Reef-1` does not exist");
  expect((await request.post(`/api/chats/${chat}/generate`, { data: {} })).status()).toBe(202);
  const gone = async () => (await (await request.get("/api/provider-list")).json()).kinds.find((each: { kind: string }) => each.kind === "chat").gone;
  await expect.poll(gone).toBe(true);
  await open(page);
  await expect(line(page).locator(".item-wrong")).toHaveText("Your provider no longer offers this model: choose another.");
  await change(page).click();
  await picker(page).getByRole("option", { name: "Reef-1" }).click();
  await use(page).click();
  await expect(says(page)).toHaveText(`Reef-1 · ${HERE} · test passed`);
  await expect(line(page).locator(".item-wrong")).toHaveText("");
});

test("the background model's line says the chat model does that work until one is picked, and a model of another provider moves the kind there", async ({ page, request }) => {
  api.models(["tide-1", "tide-1-mini", "tide-2"]);
  await store(request);
  const added = await request.post("/api/provider-list", { data: { base_url: other.url } });
  expect(added.status()).toBe(201);
  const asked = api.asked.length;
  await open(page, true);
  await expect(says(page, "Helper model")).toHaveText("Same as the chat model");

  // Every provider's models, under its name.
  const background = "Helper model";
  await change(page, "helper").click();
  await expect(picker(page, background).locator(".kind-group")).toHaveText([`${HERE} · ${host(api)} · not known whether it can do this`, `${HERE} · ${host(other)} · not known whether it can do this`]);
  await expect.poll(() => offered(page, background)).toEqual(["tide-1", "tide-1-mini", "tide-2", "duo", "solo"]);
  await picker(page, background).getByRole("option", { name: "tide-1-mini" }).click();
  await use(page).click();
  await expect(says(page, "Helper model")).toHaveText(`tide-1-mini · ${HERE} · test passed`);
  expect(api.asked.slice(asked).map((question) => question.body.model)).toEqual(["tide-1-mini"]);

  // The chat model taken at the other provider moves Chat there; the background model stays where it is.
  await open(page);
  await change(page).click();
  await picker(page).getByRole("option", { name: "solo" }).click();
  await use(page).click();
  await expect(says(page)).toHaveText(`solo · ${HERE} · test passed`);
  await open(page, true);
  await expect(says(page, "Helper model")).toHaveText(`tide-1-mini · ${HERE} · writes summaries, tags and memories`);
  expect((await stored(request)).base_url).toBe(other.url);

  // The chat model picked as the background model is none: the chat model does that work again.
  await change(page, "helper").click();
  await picker(page, background).getByRole("option", { name: "solo" }).click();
  await use(page).click();
  await expect(says(page, "Helper model")).toHaveText("Same as the chat model");
  expect((await stored(request)).worker_model).toBeNull();
});

test("the lines Search and Voice open the picker of their kind too, whose “This computer” leads to the download, and a voice at a provider is chosen on the page Voices", async ({ page, request }) => {
  api.models(["tide-1", "tide-2"]);
  await store(request);
  await open(page);

  // Search on this computer, not downloaded: its picker, with this computer's model first.
  await button(page, "Set up search").click();
  await expect(picker(page, "Search model").locator(".kind-group").first()).toHaveText("This computer");
  await expect.poll(() => offered(page, "Search model")).toContain("tide-2");
  await picker(page, "Search model").getByRole("option", { name: "tide-2" }).click();
  await use(page).click();
  await expect(says(page, "Search")).toHaveText(`tide-2 · ${HERE}`);
  // Taken back to this computer, the download's dialog opens.
  await button(page, "Change search").click();
  await picker(page, "Search model").getByRole("option", { name: /^bge-m3/ }).click();
  await use(page).click();
  await expect(page.getByRole("dialog", { name: "Search" })).toBeVisible();
  await page.getByRole("dialog", { name: "Search" }).getByRole("button", { name: "Close" }).click();
  await expect(says(page, "Search")).toHaveText("Not set up");

  // A provider's voice model leads to the page Voices, which lists that provider's voices; the stand-in lists none.
  await button(page, "Set up voice").click();
  await picker(page, "Voice model").getByRole("option", { name: "tide-1" }).click();
  await use(page).click();
  await expect(page).toHaveURL(/#\/settings\/voices$/);
  await expect(page.getByText("The provider lists no voices")).toBeVisible();
  await expect(page.getByRole("button", { name: "Make a voice from a recording" })).toHaveCount(0);
});
