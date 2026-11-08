import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { picture, SIZES, stopClock, storeModel, THEMES } from "../pictures";

// Pictures of a lorebook's editor, compared with its stored picture, pixel by pixel, at 1440 px in the light
// theme (CLAUDE.md, "Pictures of the screens"): the editor as its board draws it, with the first entry in
// view beside the panel of the entries. The database is this spec's own: a provider, and one lorebook of five
// entries.
//
// The picture is `lorebook`. The lorebook is found by its name (`camlann`), as the spec's server may be a new
// one after a test that failed, on which `beforeAll` has made it anew under another number.

const CAMLANN = {
  description: "The court, its houses and who owes whom.",
  entries: {
    0: { key: ["council", "twelve", "lords"], comment: "The Council of Twelve", content: "Twelve lords sit in council at Camlann Keep.\nThey meet at each new moon, and the eldest speaks first." },
    1: { key: ["keep", "castle", "Camlann"], comment: "Camlann Keep", content: "The keep stands over the river." },
    2: { key: [], comment: "The Royal Guard", content: "The guard wears grey.", constant: true },
    3: { key: ["oath"], comment: "The Oath", content: "Sworn at dawn.", vectorized: true },
    4: {
      key: ["ford", "river"],
      comment: "The Ford",
      content: "Shallow in summer.",
      disable: true,
      keysecondary: ["night", "flood"],
      selective: true,
      selectiveLogic: 2,
      position: 4,
      depth: 2,
      order: 30,
      probability: 40,
      useProbability: true,
      scanDepth: 6,
      caseSensitive: true,
    },
  },
};

async function make(request: APIRequestContext): Promise<void> {
  await storeModel(request, "picture-model");
  const made = await request.post("/api/lorebooks?name=Kingdom%20of%20Camlann.json", { data: Buffer.from(JSON.stringify(CAMLANN)) });
  expect(made.status(), await made.text()).toBe(201);
}

test.beforeAll(({ request }) => make(request));

/** The lorebook's address, and the reference of its last entry. */
async function camlann(request: APIRequestContext): Promise<{ address: string; ford: string }> {
  const [{ id }] = await (await request.get("/api/lorebooks?q=Camlann")).json();
  const { entries } = await (await request.get(`/api/lorebooks/${id}/edit`)).json();
  return { address: `/#/library/lorebooks/${id}`, ford: entries.at(-1).reference };
}

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;
    /** The pointer leaves for the window's corner, where it points at nothing. */
    const away = (page: Page) => page.mouse.move(width - 2, height - 2);

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the editor: the path, the first entry in view and the panel of the entries; in a narrow window the list alone", async ({ page, request }) => {
        const { address } = await camlann(request);
        await page.goto(address);
        await expect(page.locator(".lore-entries .panel-label")).toHaveText("Entries · 5");
        if (width > 960) await expect(page.locator(".entry-form .edit-head h2")).toHaveText("The Council of Twelve");
        await away(page);
        await picture(page, named("lorebook"));
      });

    });
  }
}
