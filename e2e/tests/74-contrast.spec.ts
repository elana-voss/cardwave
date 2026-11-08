import type { Locator } from "@playwright/test";
import { expect, test } from "../test";

// Words stand out from what is under them at 4.5 to 1 at least (WCAG AA): in Retrowave the account's letter in
// its round while its line is the one marked. Light's and Dark's grey and accent are the design system's own
// (docs/design.md, Open). `contrast` reads the colours as drawn: a see-through background is
// laid over what is under it, up to the first that is whole.

/** The contrast of `words`' colour on the background drawn under it. */
function contrast(words: Locator): Promise<number> {
  return words.evaluate((node: Element) => {
    const parse = (text: string): number[] => {
      const srgb = text.match(/color\(srgb ([\d.e-]+) ([\d.e-]+) ([\d.e-]+)(?: \/ ([\d.e-]+))?\)/);
      if (srgb) return [Number(srgb[1]) * 255, Number(srgb[2]) * 255, Number(srgb[3]) * 255, srgb[4] === undefined ? 1 : Number(srgb[4])];
      const [r, g, b, a] = (text.match(/[\d.]+/g) ?? []).map(Number);
      return [r, g, b, a ?? 1];
    };
    let under = [0, 0, 0, 0];
    for (let at: Element | null = node; at && under[3] < 1; at = at.parentElement) {
      const [r, g, b, a] = parse(getComputedStyle(at).backgroundColor);
      const left = 1 - under[3];
      under = [under[0] + r * a * left, under[1] + g * a * left, under[2] + b * a * left, under[3] + a * left];
    }
    const page = parse(getComputedStyle(document.body).backgroundColor);
    const left = 1 - under[3];
    const back = [0, 1, 2].map((i) => under[i] + page[i] * left);
    const [r, g, b, a] = parse(getComputedStyle(node).color);
    const front = [r, g, b].map((c, i) => c * a + back[i] * (1 - a));
    const light = (rgb: number[]) =>
      rgb.map((c) => c / 255).map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)).reduce((sum, c, i) => sum + c * [0.2126, 0.7152, 0.0722][i], 0);
    const [dim, bright] = [light(front), light(back)].sort((x, y) => x - y);
    return (bright + 0.05) / (dim + 0.05);
  });
}

test("in Retrowave the account's letter stands out in its round while its line is the one marked", async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem("theme", "retrowave"));
  await page.goto("/#/account");
  const letter = page.locator("#rail .account[aria-current=page] .initial");
  await expect(letter).toBeVisible();
  expect(await contrast(letter)).toBeGreaterThanOrEqual(4.5);
});
