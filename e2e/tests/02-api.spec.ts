import { expect, test } from "../test";

// The server's guard of its API as a page meets it: the page's own origin may write.

test("the page may write to the API of its own server", async ({ page }) => {
  await page.goto("/");
  // A browser names the page's origin on a POST; the server lets its own origin through.
  const answer = await page.evaluate(async () => {
    const upload = await fetch("/api/cards", { method: "POST", body: new Blob(["not a card"]) });
    const cards = await fetch("/api/cards");
    return { status: upload.status, body: await upload.json(), cards: await cards.json() };
  });
  expect(answer).toEqual({ status: 400, body: { code: "not_readable", error: "not a PNG file", details: { what: "png" } }, cards: [] });
});
