import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { startFakeSearch } from "../fake-search";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// Settings › Providers (board "Providers"): a box per provider with Edit (the address and the key, "Remove
// key") and Remove, which asks first; a provider no kind is at says how many models it has; and the line
// "Thinking" under a model that thinks, whose switch tries the forms of turning thinking off, one small question
// each, and keeps the first the provider takes. "Add provider" is spec 03's, the picker of a
// kind spec 21's. The box "This computer" (`.group.this-computer`, not counted among `.group.provider`) is
// first: a folder of GGUF files chosen, made by the test in the system's temporary folder, with the models that
// fit (server.mjs's "Test model" and one too large), one downloaded, put at Chat (by the API) and removed.
//
// The stand-ins `api` and `other` are on this computer, so a box shows their whole address. `o3-mini` thinks,
// as models.dev says. The picture (`providers`) is of providers whose lists the page is answered by the spec
// itself (`page.route`), as a stand-in's port is another in every run: OpenRouter with Chat and Background, and
// a program on this computer that no kind is at; nothing is asked of them.

let api: FakeProvider;
let other: FakeProvider;

test.beforeAll(async () => {
  [api, other] = await Promise.all([startFakeProvider(), startFakeProvider()]);
  api.models(["o3-mini", "tide-1"]);
  other.models(["duo", "solo"]);
});
test.afterAll(() => Promise.all([api.close(), other.close()]));

/** A key long enough for its end to be told. */
const KEY = "sk-providers-0123456789-9b3e";

const box = (page: Page, at: number) => page.locator(".group.provider").nth(at);
const head = (page: Page, at: number) => box(page, at).locator(".provider-head .item-text > .meta");
const thinking = (page: Page) => page.locator(".item.thinking");

interface Entry {
  id: number;
  name: string;
  base_url: string;
  folder: string | null;
  has_key: boolean;
}

/** Leaves the account with the chat model `model` at `api` alone, and `more` added beside it. */
async function store(request: APIRequestContext, model: string, more: FakeProvider[] = []): Promise<void> {
  for (const { id } of (await (await request.get("/api/provider-list")).json()).providers as Entry[]) await request.delete(`/api/provider-list/${id}`);
  const put = await request.put("/api/provider", { data: { base_url: api.url, model, api_key: KEY } });
  expect(put.status(), await put.text()).toBe(200);
  for (const at of more) expect((await request.post("/api/provider-list", { data: { base_url: at.url } })).status()).toBe(201);
}

const entries = async (request: APIRequestContext) => (await (await request.get("/api/provider-list")).json()).providers as Entry[];

async function open(page: Page, boxes: number): Promise<void> {
  await page.goto("about:blank");
  await page.goto("/#/settings/providers");
  await expect(page.locator(".group.provider")).toHaveCount(boxes);
}

test("a box says where the provider is and its key; Edit takes the key off, Remove asks first", async ({ page, request }) => {
  await store(request, "tide-1", [other]);
  await open(page, 2);
  await expect(head(page, 0)).toHaveText(`${api.url} · key ····9b3e`);
  await expect(box(page, 0).locator(".item-label")).toHaveText(["A program on this computer", "Chat"]);
  // The provider no kind is at: how many models it has.
  await expect(box(page, 1).locator(".item:not(.provider-head) .item-text")).toHaveText("Not used for anything yet2 models");
  await expect(head(page, 1)).toHaveText(`${other.url} · no key`);

  // Edit: the key's field says the key stored; "Remove key" and Save take it off, the address staying.
  await box(page, 0).getByRole("button", { name: "Provider menu: edit, remove" }).click();
  await page.getByRole("menuitem", { name: "Edit" }).click();
  const edit = page.getByRole("dialog", { name: "Edit provider" });
  await expect(edit.getByLabel("Address")).toHaveValue(api.url);
  await expect(edit.getByLabel("API key")).toHaveAttribute("placeholder", /9b3e/);
  await edit.getByRole("button", { name: "Remove key" }).click();
  await edit.getByRole("button", { name: "Save" }).click();
  await expect(page.locator("dialog")).toHaveCount(0);
  await expect(head(page, 0)).toHaveText(`${api.url} · no key`);
  expect((await entries(request))[0]).toMatchObject({ base_url: api.url, has_key: false });

  // Remove asks on its own line under the provider's name, which stays whole; Cancel keeps the provider, Remove takes it away.
  const remove = async () => {
    await box(page, 1).getByRole("button", { name: "Provider menu: edit, remove" }).click();
    await page.getByRole("menuitem", { name: "Remove" }).click();
    await expect(box(page, 1).locator(".provider-head + .confirm")).toContainText("Remove this provider?");
    await expect(box(page, 1).locator(".provider-head .confirm")).toHaveCount(0);
  };
  await remove();
  await box(page, 1).getByRole("button", { name: "Cancel" }).click();
  await expect(box(page, 1).getByRole("button", { name: "Provider menu: edit, remove" })).toBeFocused();
  await remove();
  await box(page, 1).getByRole("button", { name: "Remove", exact: true }).click();
  await expect(page.locator(".group.provider")).toHaveCount(1);
  expect((await entries(request)).map(({ base_url }) => base_url)).toEqual([api.url]);
});

test("the switch “Thinking” tries the forms of turning thinking off and keeps the first the provider takes", async ({ page, request }) => {
  await store(request, "o3-mini");
  await open(page, 1);
  await expect(thinking(page).locator(".meta")).toHaveText("The model thinks before it replies");
  const on = thinking(page).getByRole("switch", { name: "Chat: thinking" });
  await expect(on).toBeChecked();

  // The first form is refused, the second taken; nothing else is asked.
  const asked = api.asked.length;
  api.fail(400, "Unrecognized request argument supplied: reasoning_effort");
  await on.uncheck();
  await expect(thinking(page).locator(".meta")).toHaveText("The model replies without thinking first");
  await expect(on).not.toBeChecked();
  const bodies = api.asked.slice(asked).map(({ body }) => body);
  expect(bodies.map(({ reasoning_effort, reasoning }) => ({ reasoning_effort, reasoning }))).toEqual([
    { reasoning_effort: "none", reasoning: undefined },
    { reasoning_effort: undefined, reasoning: { enabled: false } },
  ]);

  // Kept: the page opened anew says so; turned on again, nothing is asked.
  await open(page, 1);
  await expect(on).not.toBeChecked();
  await on.check();
  await expect(thinking(page).locator(".meta")).toHaveText("The model thinks before it replies");
  expect(api.asked.length).toBe(asked + 2);
});

test("“This computer” runs the GGUF files of a folder chosen in the dialog “Folder”", async ({ page, request }) => {
  await store(request, "tide-1");
  const folder = mkdtempSync(join(tmpdir(), "cardwave-models-"));
  // It serves "Test model"'s file.
  const files = await startFakeSearch();
  try {
    for (const file of ["qwen3-4b.gguf", "gemma-3-1b.gguf", "readme.txt"]) writeFileSync(join(folder, file), "GGUF");
    await open(page, 1);
    const own = page.locator(".group.this-computer");
    await expect(own.locator(".provider-head")).toContainText("This computerRuns models from a folder on this computer · not set up");
    await own.getByRole("button", { name: "Choose a folder of models" }).click();
    const dialog = page.getByRole("dialog", { name: "Folder" });
    await dialog.getByLabel("Folder on this computer").fill(folder);
    await dialog.getByRole("button", { name: "Save" }).click();
    await expect(page.locator("dialog")).toHaveCount(0);
    await expect(own.locator(".provider-head")).toContainText(/This computer\d+ GB of RAM · /);
    await expect(own.locator(".provider-head")).toContainText(folder);
    // No line "Not used": the models that fit are listed, Cardwave's first, then the folder's own.
    const lines = own.locator(".item:not(.provider-head) .item-label");
    await expect(lines).toHaveText(["Test model", "Huge model", "gemma-3-1b.gguf", "qwen3-4b.gguf"]);
    const line = (name: string) => own.locator(".fit-model").filter({ hasText: name });
    await expect(line("Huge model").locator(".meta")).toContainText("Too large for this computer");
    await expect(line("Huge model").getByRole("button")).toHaveCount(0);
    await expect(line("qwen3-4b.gguf").locator(".meta")).toHaveText("1 KB · Runs on this computer");

    // Downloaded, a model is used for a kind and removed again.
    await line("Test model").getByRole("button", { name: "Download Test model" }).click();
    await expect(line("Test model").locator(".meta")).toContainText(" · Runs on this computer · downloaded");
    // Chosen for Chat (in Settings › Models, spec 21's), the box says so.
    const computer = (await entries(request)).find((entry) => entry.folder !== null)!;
    expect((await request.put("/api/kinds/chat", { data: { provider_id: computer.id, model: "test-model.gguf" } })).status()).toBe(200);
    await page.reload();
    await expect(line("Test model").locator(".meta")).toContainText("used for Chat");
    await expect(own.locator(".item:not(.fit-model):not(.provider-head) .item-text")).toHaveText("Chattest-model.gguf");
    await line("Test model").getByRole("button", { name: "Model menu: delete Test model" }).click();
    await page.getByRole("menuitem", { name: "Delete" }).click();
    await expect(line("Test model").locator("+ .confirm .question")).toHaveText(/^Delete this model from this computer\? It frees \S+ \S+\.$/);
    await line("Test model").locator("+ .confirm").getByRole("button", { name: "Delete" }).click();
    await expect(line("Test model").getByRole("button", { name: "Download Test model" })).toBeVisible();
  } finally {
    await files.close();
    rmSync(folder, { recursive: true, force: true });
  }
});

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the providers: one with Chat and Background, the chat model thinking, and one no kind is at", async ({ page, request }) => {
        for (const { id } of await entries(request)) await request.delete(`/api/provider-list/${id}`);
        const put = await request.put("/api/provider", { data: { base_url: "https://openrouter.ai/api/v1", model: "openai/o3-mini", api_key: "sk-or-v1-0000000000004f2a" } });
        expect(put.status(), await put.text()).toBe(200);
        expect((await request.post("/api/provider-list", { data: { base_url: "http://127.0.0.1:8080/v1" } })).status()).toBe(201);
        const [router, local] = await entries(request);
        const picked = await request.put("/api/kinds/background", { data: { provider_id: router.id, model: "openai/gpt-4o-mini" } });
        expect(picked.status(), await picked.text()).toBe(200);
        const model = (id: string, thinks = false) => ({ id, text: true, image: false, thinks });
        const lists: Record<number, object> = {
          [router.id]: { models: [model("openai/gpt-4o-mini"), model("openai/o3-mini", true)], said: true, more: false, failed: null },
          [local.id]: { models: [model("qwen3-8b"), model("gemma-3-4b"), model("llama-3.1-8b")], said: false, more: false, failed: null },
        };
        await page.route("**/api/provider-list/*/models", (route) => route.fulfill({ json: lists[Number(new URL(route.request().url()).pathname.split("/")[3])] }));
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await open(page, 2);
        await expect(thinking(page)).toHaveCount(1);
        await expect(box(page, 1)).toContainText("3 models");
        await picture(page, `providers-${width}-${theme}`);
      });
    });
  }
}
