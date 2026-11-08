import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";

// The model presets on the account's page "Advanced": "New preset" keeps the chat model in use (Settings ›
// Models) and the sampling under a name, and "Use" makes a preset's model the chat model and its values the
// sampling, with "Undo" as the way back.
//
// No test asks a provider: the addresses are ones where nothing listens (`HOME`) or that are not asked
// (`OPENROUTER`, which the list of providers has under that name). Every test stores the chat model it starts
// from (`store`) and begins without presets (`beforeEach`). `preset` keeps a preset of `THERE` past the page and
// stores what was in use again; `open` opens the page anew and waits for the list; `line` is a preset's line by
// its name, in use or not (its label has "· in use" behind the name then, so the name alone is not all of its
// text), `names` and `abouts` what the lines say, and `use` presses a line's "Use", which shows while the line
// is pointed at; `stored` is the server's provider, whose key is told by its end alone, so a key of a test is
// long enough for that (`KEY`, `OTHER_KEY`); `sent` notes what the page sends that is no reading.

const HOME = "http://127.0.0.1:1/v1";
const OPENROUTER = "https://openrouter.ai/api/v1";
const KEY = "sk-preset-home-0000-h0me";
const OTHER_KEY = "sk-or-v1-preset-0000-0r0r";

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const group = (page: Page) => page.locator(".presets");
const temperature = (page: Page) => page.getByLabel("Temperature");
const notice = (page: Page) => page.locator("#toast span");
const undo = (page: Page) => page.locator("#toast").getByRole("button", { name: "Undo" });
const asked = (page: Page) => page.getByRole("dialog");
const rest = (page: Page) => page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));

const names = (page: Page) => group(page).locator(".preset .item-label");
const abouts = (page: Page) => group(page).locator(".preset .item-text > .meta");
/** A preset's line, by the preset's name, whether it is in use or not. */
const line = (page: Page, name: string) =>
  group(page)
    .locator(".preset")
    .filter({ has: page.locator(".item-label", { hasText: new RegExp(`^${name}( · in use)?$`) }) });
const label = (page: Page, name: string) => line(page, name).locator(".item-label");

const HERE = { base_url: HOME, model: "tide-1", api_key: KEY, sampling: { temperature: 1 } };
const THERE = { base_url: OPENROUTER, model: "reef/tide-9", api_key: OTHER_KEY, sampling: { temperature: 0.7, seed: 7 } };

/** Stores the chat model a test starts from: at `HOME`, with a key and a temperature. */
async function store(request: APIRequestContext, data: object = HERE): Promise<void> {
  const put = await request.put("/api/provider", { data });
  expect(put.status(), await put.text()).toBe(200);
}

const stored = async (request: APIRequestContext) => (await request.get("/api/provider")).json();

interface Preset {
  id: number;
  name: string;
}

/** Keeps a preset of `THERE` past the page, and stores `HERE` again. */
async function preset(request: APIRequestContext, name: string): Promise<Preset> {
  await store(request, THERE);
  const made = await request.post("/api/presets", { data: { name } });
  expect(made.status(), await made.text()).toBe(201);
  await store(request);
  return made.json();
}

/** Opens the page anew and waits until the group has what it shows. */
async function open(page: Page, count: number): Promise<void> {
  await page.goto("about:blank");
  await page.goto("/#/settings/advanced");
  await expect(names(page)).toHaveCount(count);
}

async function use(page: Page, name: string): Promise<void> {
  await line(page, name).hover();
  await line(page, name).getByRole("button", { name: "Use", exact: true }).click();
}

/** Notes what the page sends to the provider's and the presets' addresses that is no reading. */
function sent(page: Page): string[] {
  const all: string[] = [];
  page.on("request", (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== "GET" && /^\/api\/(provider|presets)/.test(path)) all.push(`${request.method()} ${path}`);
  });
  return all;
}

test.describe("with a provider stored", () => {
  test.beforeEach(async ({ request }) => {
    for (const { id } of (await (await request.get("/api/presets")).json()) as Preset[]) expect((await request.delete(`/api/presets/${id}`)).status()).toBe(204);
    await store(request);
  });

  test("“New preset” keeps the chat model and the sampling in use under a name, and stores nothing", async ({ page, request }) => {
    await open(page, 0);
    await expect(group(page).locator(":scope > p")).toHaveText("A preset saves a chat model with its sampling values. Use switches to it.");
    const all = sent(page);
    // What is in use is kept: its preset is in use at once, and has the stored key.
    await group(page).getByRole("button", { name: "New preset", exact: true }).click();
    await expect(asked(page)).toHaveAccessibleName("New preset");
    const name = asked(page).getByLabel("Name", { exact: true });
    await expect(name).toBeFocused();
    await expect(name).toHaveValue("");
    // A name is needed, and has 60 signs at most.
    await name.press("Enter");
    await rest(page);
    expect(all).toEqual([]);
    await name.fill(`${"n".repeat(60)}more`);
    await expect(name).toHaveValue("n".repeat(60));
    await name.fill("  At home ");
    await name.press("Enter");
    await expect(page.locator("dialog")).toHaveCount(0);
    await expect(notice(page)).toHaveText("Preset “At home” saved.");
    await expect(names(page)).toHaveText(["At home · in use"]);
    await expect(abouts(page)).toHaveText(["A program on this computer · tide-1 · temperature 1"]);
    await expect(line(page, "At home").getByRole("button", { name: "More" })).toBeFocused();

    // Another chat model in use and a temperature typed: the next one keeps them.
    await store(request, { ...THERE, sampling: undefined });
    await temperature(page).fill("2");
    await expect.poll(async () => (await stored(request)).sampling.temperature).toBe(2);
    await group(page).getByRole("button", { name: "New preset", exact: true }).click();
    await asked(page).getByLabel("Name", { exact: true }).fill("Reef");
    await asked(page).getByRole("button", { name: "Save", exact: true }).click();
    await expect(names(page)).toHaveText(["At home", "Reef · in use"]);
    await expect(abouts(page).nth(1)).toHaveText("OpenRouter · reef/tide-9 · temperature 2");
    expect(all.filter((one) => one.includes("presets"))).toEqual(["POST /api/presets", "POST /api/presets"]);

    // A name another preset has is not taken: the dialog says why and stays, and "Cancel" leaves it.
    await group(page).getByRole("button", { name: "New preset", exact: true }).click();
    await asked(page).getByLabel("Name", { exact: true }).fill("Reef");
    await asked(page).getByLabel("Name", { exact: true }).press("Enter");
    await expect(asked(page).getByRole("alert")).toHaveText("Another preset is called “Reef”.");
    await asked(page).getByRole("button", { name: "Cancel" }).click();
    await expect(page.locator("dialog")).toHaveCount(0);
    await expect(names(page)).toHaveCount(2);

    // Each has the key of its provider: seen where it is put in use.
    const [home, reef] = (await (await request.get("/api/presets")).json()) as Preset[];
    expect((await (await request.post(`/api/presets/${home.id}/use`)).json()).provider).toMatchObject({ base_url: HOME, key_end: "h0me" });
    expect((await (await request.post(`/api/presets/${reef.id}/use`)).json()).provider).toMatchObject({ base_url: OPENROUTER, key_end: "0r0r" });
  });

  test("“Use” makes a preset's model the chat model and its values the sampling, and “Undo” puts back what was in use", async ({ page, request }) => {
    await preset(request, "Reef");
    await open(page, 1);
    await expect(temperature(page)).toHaveValue("1");

    await use(page, "Reef");
    await expect(notice(page)).toHaveText("Using “Reef”.");
    await expect(label(page, "Reef")).toHaveText("Reef · in use");
    await expect(line(page, "Reef").getByRole("button", { name: "Use", exact: true })).toHaveCount(0);
    await expect(line(page, "Reef").getByRole("button", { name: "More" })).toBeFocused();
    await expect(temperature(page)).toHaveValue("0.7");
    await expect(page.getByLabel("Seed")).toHaveValue("7");
    expect(await stored(request)).toMatchObject({ base_url: OPENROUTER, model: "reef/tide-9", key_end: "0r0r", sampling: { temperature: 0.7, seed: 7 } });

    await undo(page).click();
    await expect(label(page, "Reef")).toHaveText("Reef");
    await expect(temperature(page)).toHaveValue("1");
    await expect(page.getByLabel("Seed")).toHaveValue("");
    await expect(page.locator("#toast")).toBeEmpty();
    expect(await stored(request)).toMatchObject({ base_url: HOME, model: "tide-1", key_end: "h0me", sampling: { temperature: 1, seed: null } });
  });

  test("Edit renames a preset, and its switch has it hold the chat model and sampling in use", async ({ page, request }) => {
    await preset(request, "Reef");
    await open(page, 1);
    await line(page, "Reef").hover();
    await line(page, "Reef").getByRole("button", { name: "More" }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();
    await expect(asked(page)).toHaveAccessibleName("Edit preset");
    await asked(page).getByLabel("Name", { exact: true }).fill("Home now");
    await asked(page).getByRole("switch").check();
    await asked(page).getByRole("button", { name: "Save", exact: true }).click();
    await expect(names(page)).toHaveText(["Home now · in use"]);
    await expect(abouts(page)).toHaveText(["A program on this computer · tide-1 · temperature 1"]);
  });
});
