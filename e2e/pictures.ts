// What a spec of pictures needs beside its own database, which holds what the
// spec made and nothing else (test.ts): a provider stored, a clock that does
// not move, and a screen that lies still.
//
// `storeModel` stores a provider, of which the settings name the model, at an address where nothing listens,
// and the rest of a spec's database is what its `beforeAll` makes, the same in every run. `stopClock` stops
// the page's clock on a day long past, so that what was written now reads "Today" on any day; a day that a
// screen writes out in full (a version's) would have to be answered by the spec, and a day that a screen
// counts from is answered with `NOW`, the moment the clock stands at, as the Trash's picture answers when its
// item came there. `still` waits for the fonts and for the pictures in the window (one further down is not
// asked for and would be waited for in vain) and then has the whole page painted anew, and `picture` compares
// the window with its stored picture. Without that a picture comes out in two ways: a page first painted
// before its font has come paints its words again when it comes, with the parts of the page around them, and
// a round corner or a shadow there is a shade different than in a page painted at once (seen: the library's
// list at 600 px differed in 38 pixels around the switch "All", 12 times of 24; `npx playwright test <spec>
// --repeat-each 8` shows whether a picture holds). The pictures in the window are painted anew with the page
// (hidden for the two frames): a picture with a ground of its own is painted over that ground until the
// browser knows that it is not see-through, and what was painted is kept, so its round corners came out in two
// ways (seen: the card's page, by 4 steps of a colour). And so are the panels that lie over the page by
// themselves, the import's and the notice (`#importing`, `#toast`): the browser paints such a one apart from
// the page, so the page's new painting does not reach it, and what was built up in it line by line came out a
// shade different at a round corner in some runs (seen: the import's panel in the dark, in 3 runs of 80 and
// in 12 of 200, and in none of 400 since); what is pointed at in one, or holds the focus there, would lose
// that while it is hidden for those frames. A picture has to hold alone too, first in a new
// browser, which is how `-g` runs it, and a run in which a test before it failed: the
// tests of a spec file share a browser, and what was painted there before changes what a later page paints
// (seen: the card's page alone differed from the same test as the file's seventh), so a new picture is run
// once by itself (`-g "1440 px, light.*<part of its title>"`: the `›` Playwright prints between a group's name
// and a test's is no part of a title, and a `-g` with it finds no test).
//
// How a picture is compared, kept and renewed. playwright.config.ts has every picture compared exactly
// (`threshold: 0`, `maxDiffPixels: 0`; Playwright's own threshold of 0.2 lets a small change of a colour
// pass); where a picture differs between two runs of the same code, what moves is taken out (an animation, a
// caret, a time shown, what a test before it left), and the comparison is not loosened. A screen is pictured
// once, in one state its board draws, at 1440 px in the light theme (`SIZES`, `THEMES`, one of each; a spec
// is written for any size and theme, so one added there pictures every screen in it too), with data of the
// test's own, the same in every run; the pictures are in git, beside their spec, as
// `<screen>-<width>-<theme>-win32.png`. After a change of look that is wanted they are renewed (`npx
// playwright test <spec file> --update-snapshots` in e2e), and of each screen the change was meant for one
// renewed picture (`git status --short`) is looked at against its board; a picture of another screen that
// changed is a change not meant, and is looked into. Where a renewed picture should differ in one place only, a
// copy of the pictures from before is compared with them: `ImageChops.difference(old, new).getbbox()` of
// Pillow gives the box around the pixels that changed (Pillow is not installed: `pip install --target
// <scratchpad>/pylib pillow`, then `PYTHONPATH`). A spec of pictures that is new is tried once: one value in
// web/src/styles.css is changed by hand and the test seen to fail.
//
// A screenshot of anything else, to look at: a throwaway spec in tests/ (with the `test` of test.ts, as every
// spec) that sets the window's size and writes PNGs into the scratchpad, run by its file name and deleted
// afterwards.
//
// Traps met: a test that changes the data puts it back for the tests after it;
// the settings' line "Cache" says how much the lists before it asked for, so that picture clears the cache
// first; the pointer is moved to the window's corner where it would lie on a row; without
// `--update-snapshots` a picture that is not there is written and its test fails all the same; animations and
// the caret are taken out by Playwright itself; a picture's file that changes moves pixels elsewhere on the
// page too (seen: with the logo scaled down, the round corners of some cards' pictures came out a shade
// different), so where pictures differ after such a change, the place is looked up before they are renewed; a
// part that stays in view while its page scrolls (`position: sticky`) keeps the fractions of a pixel it was
// first painted at, so when what stands over it changes its height afterwards (a picture that comes), its
// lines of words are a pixel off (seen: the card's column of tags), which is why the card's picture has its
// place before it comes, and why a spec waits for a picture before it scrolls or opens anything; a screen
// that reads what it shows a second time draws it anew, with its pictures, so a spec waits for the last
// reading before its picture (a chat is read again once the page hears the server, `open` in
// tests/32-chat-pictures.spec.ts); a field for a number writes a fraction as the system does ("0,8" on
// this machine), so a picture has whole numbers in such fields (tests/34-account-pictures.spec.ts); what
// stands in the rail as a button in a link's place (the account) comes out with a few pixels of its letters'
// edges another shade in the drawer, though it is laid out as the link was (seen: 8 and 10 pixels of 540,000).
import { expect, type APIRequestContext, type Locator, type Page } from "@playwright/test";

/** The sizes a screen is pictured at, and the themes: one of each. A spec is written for any size and theme, so a size or theme added here pictures every screen in it too. */
export const SIZES = [[1440, 900]] as const;
export const THEMES = ["light"] as const;

/**
 * Stores a provider whose chat model is `model`, which the settings name, at
 * an address where nothing listens: no screen asks it anything by itself.
 */
export async function storeModel(request: APIRequestContext, model: string): Promise<void> {
  const provider = await request.put("/api/provider", { data: { base_url: "http://127.0.0.1:1/v1", model, sampling: {} } });
  expect(provider.status(), await provider.text()).toBe(200);
}

/** The moment the page's clock is stopped at. */
export const NOW = new Date("2026-01-01T12:00:00");

/**
 * Stops the page's clock at a day long past, before the page is opened: what
 * the server tells of as written now reads "Today" on whatever day the spec
 * runs. A screen that writes a day out in full, or counts the days from one,
 * has that day answered by the spec.
 */
export const stopClock = (page: Page) => page.clock.setFixedTime(NOW);

/**
 * Waits until the screen lies still: its fonts are there, the pictures in the
 * window have come (one further down is not asked for until it is scrolled
 * to), and two frames have passed. Then the whole page is painted anew. A
 * page that was painted before its font had come has the words painted again
 * when it comes, and with them the parts of the page around them, over what
 * was there: a round corner or a shadow in such a part comes out a shade
 * different than in a page painted at once. Whether the font comes first is a
 * matter of milliseconds, so a picture came out in two ways (seen: the
 * library's list at 600 px, 12 times of 24). Another ground under the page
 * for two frames has all of it painted again, the same way every time. A root
 * that is see-through for two frames does so too, but leaves the words of
 * some screens without the colours at their edges (seen: Discovery). The
 * pictures in the window are hidden for those frames, and so painted anew
 * themselves, once they are read: one with a ground of its own is painted
 * over that ground until the browser knows that it is not see-through, and
 * its round corners came out a shade different by whether it knew at the
 * first painting (seen: the card's page). The panels that lie over the page
 * by themselves are hidden for those frames too: the browser paints them
 * apart from the page, whose new painting does not reach them.
 */
export async function still(page: Page): Promise<void> {
  await page.evaluate(async () => {
    await document.fonts.ready;
    const inView = [...document.images].filter((picture) => {
      const at = picture.getBoundingClientRect();
      return at.width > 0 && at.bottom > 0 && at.top < innerHeight;
    });
    const come = (picture: HTMLImageElement) => (picture.complete ? Promise.resolve() : new Promise((done) => (picture.onload = picture.onerror = done)));
    await Promise.all(inView.map((picture) => come(picture).then(() => picture.decode().catch(() => {}))));
    const frames = () => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)));
    await frames();
    const over = [...document.querySelectorAll<HTMLElement>("#importing, #toast")];
    document.body.style.backgroundColor = "rgb(1 2 3)";
    for (const picture of [...inView, ...over]) picture.style.visibility = "hidden";
    await frames();
    document.body.style.backgroundColor = "";
    for (const picture of [...inView, ...over]) picture.style.visibility = "";
    await frames();
  });
}

/** Compares the window with its stored picture `name`, once the screen lies still; `mask` covers what reads the real clock. */
export async function picture(page: Page, name: string, mask: Locator[] = []): Promise<void> {
  await still(page);
  await expect(page).toHaveScreenshot(`${name}.png`, { mask });
}
