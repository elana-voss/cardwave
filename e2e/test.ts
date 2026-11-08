// The `test` every spec file is written with: Playwright's, on a server of the spec file's own.
// A spec file begins with a database that is empty, so it makes all it needs itself, the model
// provider too, and passes alone, in any order and beside the others.
//
// A spec file imports `test` and `expect` from here, never from `@playwright/test`: this `test` starts the
// file's server when its first test, or its `beforeAll`, asks for the address (`serve` in server.mjs, on the
// port of its worker, `ports`), and without it a test has no address to open. The numbers in the files' names
// say nothing of an order. Model replies come from fake-provider.ts and cards from card.ts; a spec of
// pictures has pictures.ts; the chat and image models are stored as first run stores them by stored.ts. A spec's own helpers and traps are in its head comment, and what follows holds
// for every spec, each learned in the one named.
//
// The file's server and what is on it. A file's tests run one after the other on its one database, so a test
// looks only at what it made itself, or removes what it must not meet, as 07-personas and 08-lorebooks do
// before each test. A test that fails in a file that is not `serial` has the tests after it start in a new
// worker, so on a new server, where `beforeAll` runs again: what the tests before the failure made is gone.
// In a file whose tests run one after the other (`serial`), tests picked with `-g` do not run after one of
// them failed. `restartServer` closes the file's server and opens it on the same data, as the app is (spec 46). A
// file's server has no provider until the file stores one: until then a start without an
// address (`page.goto("/")`) shows first run, so a test names the screen it wants (`/#/chats`). The tests
// that fill the account's form open `/#/settings/advanced` (spec 03, and spec 21 from the settings' line). A chat started without a persona named starts as the default persona, if the file has
// made one by then. A test prepares through `request` (plain HTTP to the server) and fakes a failing answer
// with `page.route`. An answer is held back until the page has moved on by a `page.route` that waits for a
// promise before `route.fallback()` (`holdFirst` in spec 21).
//
// Moving between screens. A hash-only `page.goto` does not load the page anew, so what a screen keeps while
// the app runs is still there. A click that changes the address shows the next screen a moment later, and a
// `page.goto` right after it overtakes it, so that the screen between is never made: a test waits for
// something only the new screen has before it looks at what both have or goes on (seen in spec 10, where the
// editor and the card's page both have the switch between the characters). `page.goBack()` comes back also
// where the entry before has the same address (seen in spec 20, after "Confirm"). A form that is opened as
// soon as its screen is made (Create > New persona) is there before the screen's list, and the list, when it
// comes, is drawn around it: a field that had the focus loses it unless it is given back (`draw` in
// web/src/views/personas.ts), and a `fill` that meets that moment types nowhere (seen: the test passed here
// and failed in another copy of this folder); such a test holds the list back itself
// (`page.route`).
//
// Finding a thing. `toContainText` and `toHaveText` read what is hidden too: whether a line shows is asked of
// the line itself (`getByText(...)` with `toBeVisible` or `toBeHidden`; seen in spec 11). `getByText` finds a
// part of a text too, and a card's row has its names twice, beside the title for a wide window and in the
// line of names and tags for a narrow one: such a text is asked for with `exact: true`, which finds an
// element whose whole text it is, so not a label with more words behind its name (seen in spec 37, whose
// line in use is found by a pattern over the label). `getByRole` does not
// find what is hidden, so the heading of a panel that is hidden is asked for by its place (`#importing h2`,
// seen in spec 28). `getByRole("option")` finds the options of a `select` too (spec 18 asks for the lines
// inside its list). `getByLabel` finds a button by its `aria-label` too, and by a part of it: with a button
// named "Change the chat model" on the page, the form's field is asked for with `getByLabel("Model", { exact:
// true })` (seen in the specs 03 and 17). An element without anything in it counts as hidden for
// `toBeHidden`, whatever its `hidden` says. A
// notice may carry a button ("Undo"), so its words are asked of `#toast span`; it goes the
// moment its button is pressed, before what the button does is done, so a test waits for that itself
// (`expect.poll`). A dialog is taken out of the page a moment after it closes, so a test waits for
// that with `expect(page.locator("dialog")).toHaveCount(0)`.
//
// The rail. It has links called Characters, Lorebooks and Personas, as the library's tabs have, and its
// "Library" and "Characters" have one address: a test asks for a link inside its place (`#rail`, or the
// `navigation` "Library sections") and by its name, and for what the rail marks with `#rail
// [aria-current]`, which on the account's pages is no link: the account is a button, which opens the menu of
// the account's pages (Profile, Settings, and Server of this computer's account). It reads "Llocal" (its letter and its name) and is called
// "Account: local", so it is asked for by its accessible name (`/^Account/`, `toHaveAccessibleName`), and the
// gear beside it is the link "Settings". In a window of 600 px or less the rail is hidden until the button
// "Open menu" shows it as the drawer, and the bar `#topbar` has the screens' links, the account's button and
// a marked one of its own (`#topbar [aria-current]`); `getByRole` finds the one of the two that shows. The
// account's name is asked of the server once while the app runs (web/src/account.ts), so a test that answers
// `/api/account` itself starts the app anew (`page.reload`, or from `about:blank`). The rail says nothing of the
// connection: that the page is heard is the server's `hello` on the socket (`page.on("websocket")` in spec
// 01); its first `hello` has the screen read and draw itself anew, closing a menu opened before it, so a
// picture of an open menu waits for it (`open` in spec 31). The socket's address carries the page's mark (`/ws?page=…`), which a
// string does not match: a route names it by `SOCKET`, from here. A change the page makes itself is not told
// to it; one made in a second page (`page.context().newPage()`) or by `request` is, and
// `deafen`, from here, has a page miss it until its socket drops and it connects again.
//
// Lists and rows. A search field searches 200 ms after the last key and draws its list anew then, and a
// scroll is told to the page a frame after it was made: a test that needs the list to lie still (a
// right-click, a measured box) searches through `find` and waits with `rest` (spec 05). A list's order is
// chosen in the panel "Sort and filter", so a spec that needs the cards by name opens it. A card's row has a link over all of it, so a click asked of the row's picture or words waits in vain
// for them to be what is hit (seen: 30 s, then the test's end): the mouse is pressed at the part's middle
// (`press` in spec 14). The list of chats has its order in the panel "Sort". A picture has its shape on the page only once it has come, and a list's comes later
// than the list: a test that measures one waits for it first (`pixels` of spec 30, or in Discovery the
// blurred copy `.art-bg`, which is there from then on; seen in spec 05, which measured a picture without
// width and height). The import's panel takes the next import's files while it shows something it keeps (a
// file that failed, a lorebook offered), so a test closes it before an import that is to stand alone (seen in
// the specs 08 and 28).
//
// The chat. A greeting has "Regenerate" too, so a test that sent a message waits for the reply's message
// before it waits for that button (`say` in the specs 06 and 08). A hover waits until nothing lies over the
// thing, and in a narrow window the open side panel lies over the message field (seen: the test ran out of
// time without saying where); a press on the chat closes that panel, and it glides in, so a test that
// measures it asks for less motion first (`page.emulateMedia`). What is done with a message is in its menu
// "…", whose button shows while the message is pointed at (`pick` in spec 03); each message has
// that button, "Message options", so the message field is asked for with `getByLabel("Message", { exact:
// true })` (seen in spec 05). A message shows narration without its asterisks, so a text is asked for
// without them. Who replies is a pill over the message field and its menu, whose lines are in the page while
// it is shut too (`replier`, `lines` and `choose` in the specs 24 and 25). A menu's line that cannot be
// picked is no disabled button (`aria-disabled`): `toBeDisabled` sees it, and a press on it has to be forced.
//
// Keys, fields and the focus. A choice from a list is the app's own select field, a button labelled by its
// label, whose words are the choice made: `pickFrom` picks a line of it and `linesOf` are its lines. An Enter that must not save a form is tested on a form that could be saved as it stands,
// as the browser does not send one with a field that is required and empty. Escape in a search field that has
// words empties the field, and closes the window the field stands in only when pressed again (seen). What the
// browser itself offers under a field (a `datalist`) opens in no test, in a window that shows or not, and
// takes no key from one (seen), which is why the model's field has `suggest` of web/src/dom.ts.
//
// Sizes. The tests' browser hides scrollbars, so one too many shows in no test and no screenshot (seen:
// `overflow-y: auto` makes a box scroll sideways too): a spec file that begins with `test.use({
// launchOptions: { ignoreDefaultArgs: ["--hide-scrollbars"] } })` has them, 15 px wide; it
// holds for the whole file and cannot be set for one test. A dialog's corners are round, 16 px, and a click 4
// px inside the corner of its box is one beside it, which closes it. At 600 px a button at
// the right of a box's line is 112 px wide, not 140 px. A line of a group under another has the rule over it
// inside its box, so what stands in its middle is half a pixel lower than the box's middle (seen).
import { expect, test as base, type Locator, type Page, type WebSocketRoute } from "@playwright/test";
import { serve } from "./server.mjs";

export { expect } from "@playwright/test";

/** The lines of the app's select field whose button is `field`, shown or not: for `toHaveText`, and to press once it is open. */
export const linesOf = (field: Locator) => field.locator("xpath=..").getByRole("menuitemradio", { includeHidden: true });

/** Picks the line called `label` of the app's select field whose button is `field`: opens its menu and presses the line. */
export async function pickFrom(field: Locator, label: string): Promise<void> {
  await field.click();
  await field.locator("xpath=..").getByRole("menuitemradio", { name: label, exact: true }).click();
}

/** The line `name` of the view menu (the eye) of the bar shown, the title bar's or at 600 px the narrow bar's; opens the menu. */
export async function viewLine(page: Page, name: string): Promise<Locator> {
  await page.locator("button[aria-label=View]:visible").click();
  return page.locator("[role=menu][aria-label=View]:visible").getByRole(name === "Compact" ? "menuitemcheckbox" : "menuitemradio", { name, exact: true });
}

/** Chooses `name` in the view menu: a view of the page, a theme, or Compact. */
export const chooseView = async (page: Page, name: string) => (await viewLine(page, name)).click();

/** The address of the page's event socket, which carries the page's mark, for `routeWebSocket`. */
export const SOCKET = /\/ws\?page=/;

/**
 * Has `page` hear nothing the server tells it after its first word, until what this answers is called: that
 * closes the socket, the page connects again as after a drop, and hears all from then on. Called before the
 * app is opened, which it is once before that.
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

/** Answers the address of the server a spec file runs on; `restart` closes and opens that server, as the app is. */
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
  baseURL: async ({ servers }, use, info) => use(await servers.at(info.file)),
  // Closes the file's server and opens it again on the same data, as when the app is closed and opened.
  restartServer: async ({ servers }, use) => use(() => servers.restart()),
});
