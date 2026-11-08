import { expect, test } from "../test";
import { cardFile } from "../card";

// The pages' Content-Security-Policy (milestone 104), the second guard behind showing a stranger's texts as text:
// should a future change put a card's words into the page as HTML, what they carry does not run. The test makes
// that defect itself: it puts the card's description back into the page as HTML, and a script element beside it.

test("a script in a card's text does not run, even put into the page as HTML", async ({ page, request }) => {
  const words = `<img src="/nothing.png" onerror="window.injected = 'handler'">`;
  const response = await request.post("/api/cards", { data: cardFile({ name: "Vex Harrow", description: words, first_mes: "Hello." }) });
  expect(response.status()).toBe(201);
  const card = (await response.json()).card_id;
  const answer = await page.goto(`/#/library/${card}`);
  const shown = page.getByText(words).first();
  await expect(shown).toBeVisible();

  const ran = await shown.evaluate(async (node) => {
    node.innerHTML = node.textContent ?? "";
    const picture = node.querySelector("img");
    if (picture) await new Promise((done) => picture.addEventListener("error", done, { once: true }));
    document.body.append(Object.assign(document.createElement("script"), { textContent: "window.injected ??= 'script'" }));
    await new Promise((done) => setTimeout(done, 100));
    return (window as unknown as { injected?: string }).injected ?? "nothing";
  });
  expect(ran).toBe("nothing");
  expect(answer?.headers()["content-security-policy"]).toContain("script-src 'self'");
});

test("the page lets pictures from other websites load only while Settings shows them, from the next page load", async ({ page, request }) => {
  const policy = async () => (await page.goto("/"))?.headers()["content-security-policy"] ?? "";
  expect(await policy()).toContain("img-src 'self' data: blob:;");
  expect((await request.patch("/api/settings", { data: { web_pictures: true } })).status()).toBe(200);
  expect(await policy()).toContain("img-src 'self' data: blob: http: https:;");
  expect((await request.patch("/api/settings", { data: { web_pictures: false } })).status()).toBe(200);
  expect(await policy()).toContain("img-src 'self' data: blob:;");
});
