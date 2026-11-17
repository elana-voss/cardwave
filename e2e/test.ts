// The `test` every spec file is written with: Playwright's, on a server of the spec file's own. A spec file
// begins with an empty database, so it makes all it needs itself, the model provider too, and passes alone, in
// any order and beside the others (the numbers in the files' names say nothing of an order).
//
// Import `test` and `expect` from here, never from `@playwright/test`: this `test` starts the file's server
// when its first test, or its `beforeAll`, asks for the address (`serve` in server.mjs, on the port of its
// worker). Model replies come from fake-provider.ts, cards from card.ts, a spec of pictures has pictures.ts,
// and the chat and image models are stored as first run stores them by stored.ts. A spec's own helpers and
// traps are in its head comment.
//
// The file's server. A file's tests run one after the other on its one database, so a test looks only at what
// it made itself or removes what it must not meet (07-personas, 08-lorebooks). A test that fails in a file that
// is not `serial` has the tests after it start in a new worker, on a new server, where `beforeAll` runs again;
// in a `serial` file tests picked with `-g` do not run after one of them failed. A file's server has no
// provider until the file stores one: until then `page.goto("/")` shows first run, so a test names the screen
// it wants (`/#/chats`). A test prepares through `request` (plain HTTP to the server) and fakes a failing
// answer with `page.route`; an answer is held back by a `page.route` that waits for a promise before
// `route.fallback()` (`holdFirst` in spec 21).
//
// Moving between screens. A hash-only `page.goto` does not load the page anew. A click that changes the
// address shows the next screen a moment later, and a `page.goto` right after it overtakes it: a test waits for
// something only the new screen has first (seen in spec 10). A form opened as soon as its screen is made is
// there before the screen's list, and the list, when it comes, is drawn around it: a field loses the focus
// unless it is given back (`draw` in web/src/views/personas.ts), and a `fill` that meets that moment types
// nowhere, so such a test holds the list back itself (`page.route`).
//
// Finding a thing. `toContainText` and `toHaveText` read what is hidden too: whether a line shows is asked of
// the line itself (`getByText` with `toBeVisible`/`toBeHidden`). `getByText` finds a part of a text too, so a
// text that stands twice (a card's name beside the title and in the line of names) is asked for with
// `exact: true`. `getByRole` does not find what is hidden, so a hidden panel's heading is asked for by its place
// (`#importing h2`). `getByLabel` finds a button by a part of its `aria-label` too, so a field named like a
// button is asked for with `{ exact: true }` (spec 17). An element with nothing in it counts as hidden. A
// notice's words are asked of `#toast span`: it goes the moment its button is pressed, before what the button
// does is done (`expect.poll`). A dialog is taken out of the page a moment after it closes
// (`expect(page.locator("dialog")).toHaveCount(0)`).
//
// Screens. The rail has links called Characters, Lorebooks and Personas as the library's tabs have, so a test
// asks inside its place (`#rail`, or the `navigation` "Library sections"); the account is a button in the rail
// (accessible name `/^Account/`), the gear beside it the link "Settings"; at 600 px or less the rail is a
// drawer and `#topbar` has the links (`getByRole` finds the one that shows). The account's name is asked of the
// server once while the app runs, so a test that answers `/api/account` itself starts the app anew. A search
// field searches 200 ms after the last key, and a scroll is told a frame after: a test that needs a list to lie
// still searches through `find` and waits with `rest` (spec 05); a card's row has a link over all of it, so a
// click on its parts is pressed at the part's middle (`press`, spec 14). A picture has its shape only once it
// has come: a test that measures one waits for it first. The import's panel takes the next import's files
// while it shows something it keeps, so a test closes it first (specs 08, 28). A greeting has "Write again"
// too, so a test that sent a message waits for the reply's message first (`say`); a message's menu "…" shows
// while it is pointed at (`pick`, spec 03); a menu's line that cannot be picked is `aria-disabled`, not
// disabled, and a press on it has to be forced. Keys: Enter does not send a form with a field that is required
// and empty; Escape in a search field with words empties it and closes its window only when pressed again.
//
// Sizes. The tests' browser hides scrollbars: a spec file that begins with `test.use({ launchOptions: {
// ignoreDefaultArgs: ["--hide-scrollbars"] } })` has them, 15 px wide, for the whole file. A dialog's corners
// are 16 px round, and a click 4 px inside the corner of its box is one beside it, which closes it.
import { expect, test as base, type Locator, type Page, type WebSocketRoute } from "@playwright/test";
import { serve } from "./server.mjs";

export { expect } from "@playwright/test";

/** The lines of the app's select field whose button is `field`, shown or not: for `toHaveText`, and to press once it is open. A choice from a list is the app's own select field, a button labelled by its label, whose words are the choice made. */
export const linesOf = (field: Locator) => field.locator("xpath=..").getByRole("menuitemradio", { includeHidden: true });

/** The button called `name`, exactly. */
export const button = (page: Page, name: string | RegExp) => page.getByRole("button", { name, exact: true });

/** The chat's message field: each message has a button "Message options", so a part of its label does not find it. */
export const composer = (page: Page) => page.getByLabel("Message", { exact: true });

/**
 * Sends `text` and waits for the reply to it. A greeting has "Write again" too, so it waits for the reply's
 * message (two more than before) before it waits for that button.
 */
export async function say(page: Page, text: string): Promise<void> {
  const before = await page.locator("article.message").count();
  await composer(page).fill(text);
  await composer(page).press("Enter");
  await expect(page.locator("article.message")).toHaveCount(before + 2);
  await expect(button(page, "Write again")).toBeEnabled();
}

/** Picks the line called `label` of the app's select field whose button is `field`: opens its menu and presses the line. */
export async function pickFrom(field: Locator, label: string): Promise<void> {
  await field.click();
  await field.locator("xpath=..").getByRole("menuitemradio", { name: label, exact: true }).click();
}

/** Answers the list of providers as of a user who has added none, as one kept there would open first run at step 2; other than reading it goes through. */
export async function noneAdded(page: Page): Promise<void> {
  await page.route("**/api/provider-list", async (route) => {
    if (route.request().method() !== "GET") return route.fallback();
    const response = await route.fetch();
    return route.fulfill({ response, json: { ...(await response.json()), providers: [] } });
  });
}

/** A model's line in a model picker `scope`, by its ID: the line's title (its name is the readable one, the ID shows on hover). */
export const modelLine = (scope: Locator, id: string) => scope.locator(`[role="option"][title="${id}"]`);

/** The line `name` of the view menu (the eye) of the bar shown, the title bar's or at 600 px the narrow bar's; opens the menu. */
export async function viewLine(page: Page, name: string): Promise<Locator> {
  await page.locator("button[aria-label=View]:visible").click();
  return page.locator("[role=menu][aria-label=View]:visible").getByRole(name === "Compact" ? "menuitemcheckbox" : "menuitemradio", { name, exact: true });
}

/** Chooses `name` in the view menu: a view of the page, a theme, or Compact. */
export const chooseView = async (page: Page, name: string) => (await viewLine(page, name)).click();

/** The address of the page's event socket, which carries the page's mark (`/ws?page=…`, which a string does not match), for `routeWebSocket`. Its first `hello` has the screen read and draw itself anew, closing a menu opened before it (`open` in spec 31); that the page is heard is asked in spec 01 (`page.on("websocket")`). */
export const SOCKET = /\/ws\?page=/;

/**
 * Has `page` hear nothing the server tells it after its first word, until what this answers is called: that
 * closes the socket, the page connects again as after a drop, and hears all from then on. Called before the
 * app is opened, which it is once before that. A change the page makes itself is not told to it; one made in a second page or by `request` is.
 */
export async function deafen(page: Page): Promise<() => Promise<void>> {
  const sockets: WebSocketRoute[] = [];
  await page.routeWebSocket(SOCKET, (socket) => {
    const first = sockets.length === 0;
    sockets.push(socket);
    const server = socket.connectToServer();
    let heard = false;
    server.onMessage((message) => {
      if (first && heard) return;
      heard = true;
      socket.send(message);
    });
  });
  return async () => {
    await expect.poll(() => sockets.length).toBe(1);
    await sockets[0].close();
  };
}

/** Answers the address of the server a spec file runs on; `restart` closes and opens that server on the same data, as the app is (spec 46). */
type Servers = { at(file: string): Promise<string>; restart(): Promise<void> };

export const test = base.extend<{ restartServer: () => Promise<void> }, { servers: Servers }>({
  // A worker runs one spec file after the other, so it has one server at a time: the next file's is started
  // when its first test, or what it does before all of them, asks for the address.
  servers: [
    async ({}, use, worker) => {
      let running: { url: string; stop(): Promise<void>; restart(): Promise<void> } | null = null;
      let of = "";
      await use({
        at: async (file) => {
          if (!running || file !== of) {
            await running?.stop();
            running = null;
            running = await serve(worker.parallelIndex);
            of = file;
          }
          return running.url;
        },
        restart: async () => running?.restart(),
      });
      await running?.stop();
    },
    { scope: "worker" },
  ],
  // The spec file is the title path's first: `info.file` is where the test is written, sweep.ts for every sweep spec.
  baseURL: async ({ servers }, use, info) => use(await servers.at(info.titlePath[0])),
  // Closes the file's server and opens it again on the same data, as when the app is closed and opened.
  restartServer: async ({ servers }, use) => use(() => servers.restart()),
});
