import type { Page } from "@playwright/test";
import { expect, test } from "../test";

// Run-through "making a character together": each style (Tree, Cloud, Hybrid) on the pretend model, by clicks and
// typing alone: the style chosen in Settings › Advanced, the interview from Create's line asked to its end, the
// read-back with one line struck, Make the character, the new character's page. The steps' details are 82's. Run
// with RUN_THROUGHS=1 only (playwright.config.ts).
//
// Trap: the pretend model fills what a form asks with what its schema allows, so what each question says is not
// known; the loop answers whatever comes, by the field or the first pill.

test.describe.configure({ mode: "serial" });

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });

test.beforeAll(async ({ request }) => {
  const provider = await request.put("/api/provider", { data: { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" } });
  expect(provider.status()).toBe(200);
});

/** Answers each question until the read-back stands; at most 40, as an endless interview is a defect. */
async function answerAll(page: Page): Promise<void> {
  const list = page.locator(".readback");
  const go = button(page, "Next");
  for (let turn = 0; turn < 40; turn += 1) {
    await expect(list.or(go)).toBeVisible();
    if (await list.isVisible()) return;
    const field = page.getByLabel("Your answer");
    if (await field.isVisible()) await field.fill("Someone who listens, at the end of a long day.");
    else if (await go.isDisabled()) await page.locator(".ask .pill").first().click();
    await go.click();
  }
  throw new Error("the interview did not end in 40 answers");
}

for (const [name, style] of [["Tree", "tree"], ["Cloud", "cloud"], ["Hybrid", "hybrid"]]) {
  test(`${name}: from the style's choice through the questions and the read-back to the written character`, async ({ page, request }) => {
    await page.goto("/#/settings/advanced");
    const line = page.getByRole("group", { name: "Make a character together" });
    await line.getByRole("button", { name }).click();
    await expect(line.getByRole("button", { name })).toHaveAttribute("aria-pressed", "true");

    await page.locator("#rail").getByRole("button", { name: "Create" }).click();
    await page.getByRole("menuitem", { name: "New character" }).click();
    await page.getByRole("link", { name: /^Make a character together/ }).click();
    await answerAll(page);

    await expect(page.getByText("Here is what I understood.")).toBeVisible();
    const first = page.locator(".readback > *").first();
    await first.getByRole("button", { name: "Remove" }).click();
    await expect(first.locator("s")).toBeVisible();

    const written = page.waitForResponse("**/api/interview/write");
    await button(page, "Make the character").click();
    const response = await written;
    expect(response.status(), await response.text()).toBe(201);
    const sent = response.request().postDataJSON();
    expect(sent.interview.style).toBe(style);
    expect(sent.verdicts[0]).toBe("remove");
    const made = await response.json();
    await expect(page).toHaveURL(new RegExp(`#/library/${made.card_id}`));
    if (made.persona.length > 0) await button(page, "Not now").click();
    expect((await (await request.get("/api/unsaved/interview")).json())?.text ?? "").toBe("");
  });
}
