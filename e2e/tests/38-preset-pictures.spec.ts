import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// Pictures of the presets on the account's page "Advanced", compared with their stored pictures, pixel by
// pixel, at 1440 px in the light theme (CLAUDE.md, "Pictures of the screens"): the model presets with a line
// pointed at, over the prompt presets and Sampling; and a prompt preset's editor. The page without a preset is the
// picture `advanced` of 34-account-pictures.spec.ts.
//
// The pictures are `presets` and `prompt-preset`. The database is this spec's own: three model presets, each
// made of the chat model stored before it, the last, "Everyday", at an address where nothing listens and with a
// whole number for its temperature (a field writes a fraction as the system does, ../pictures.ts), so that it is
// the one in use; and two prompt presets, of which "Noir" is in use (`make`). A line's tools show while it is
// pointed at, so the picture points at "Long nights".

async function make(request: APIRequestContext): Promise<void> {
  const here = { base_url: "http://127.0.0.1:1/v1", model: "picture-model", sampling: { temperature: 1, max_response_length: 800 } };
  const provider = await request.put("/api/provider", { data: { ...here, api_key: "sk-picture-key-0000" } });
  expect(provider.status(), await provider.text()).toBe(200);
  // A preset keeps the chat model in use, so each is stored first; what is in use at the end is "Everyday"'s.
  const preset = async (name: string, holds: object) => {
    const stored = await request.put("/api/provider", { data: holds });
    expect(stored.status(), await stored.text()).toBe(200);
    const made = await request.post("/api/presets", { data: { name } });
    expect(made.status(), await made.text()).toBe(201);
  };
  await preset("Long nights", { base_url: "https://openrouter.ai/api/v1", model: "anthropic/claude-opus-4.5", api_key: "sk-or-v1-0000000000000000", sampling: { temperature: 0.7 } });
  await preset("Attic", { base_url: "http://127.0.0.1:5001/v1", model: "attic-7b", sampling: {} });
  await preset("Everyday", { ...here, api_key: "sk-picture-key-0000" });
  const prompt = async (name: string, system_prompt: string, authors_note: string) => {
    const made = await request.post("/api/prompt-presets", { data: { name, system_prompt, authors_note, authors_note_depth: 4 } });
    expect(made.status(), await made.text()).toBe(201);
    return (await made.json()).id as number;
  };
  noir = await prompt("Noir", "Write as a hard-boiled noir narrator. Short sentences, rain, neon.", "[Keep {{char}} terse and wary.]");
  await prompt("Short replies", "", "[Reply in at most three sentences.]");
  const use = await request.put("/api/prompt-presets/in-use", { data: { id: noir } });
  expect(use.status(), await use.text()).toBe(204);
}

/** The prompt preset in use, whose editor is pictured. */
let noir = 0;

test.beforeAll(({ request }) => make(request));

const line = (page: Page, name: string) => page.locator(".preset", { hasText: name });

/** Opens the page beside the folded rail and waits for the sampling and the three presets. */
async function open(page: Page): Promise<void> {
  await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
  await page.goto("/#/settings/advanced");
  await expect(page.getByLabel("Temperature")).toHaveValue("1");
  await expect(page.locator(".presets .preset .item-label")).toHaveText(["Attic", "Everyday · in use", "Long nights"]);
  await expect(page.locator(".prompt-presets .preset .item-label")).toHaveText(["Default", "Noir · in use", "Short replies"]);
}

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the presets over the form: the one in use, and “Use” and the menu's button of the line pointed at", async ({ page }) => {
        await open(page);
        // The page's end, once every part has come: a part that came after the hover moved the scroll (seen once).
        await page.waitForLoadState("networkidle");
        await page.locator(".main").evaluate((main) => main.scrollTo(0, main.scrollHeight));
        await line(page, "Long nights").hover();
        await expect(line(page, "Long nights").locator(".preset-tools")).toHaveCSS("opacity", "1");
        await picture(page, named("presets"));
      });

      test("a prompt preset's editor", async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await page.goto(`/#/settings/advanced/prompts/${noir}`);
        await expect(page.getByLabel("System prompt")).toHaveValue(/^Write as a hard-boiled/);
        await page.getByLabel("Name").blur();
        await picture(page, named("prompt-preset"));
      });

    });
  }
}
