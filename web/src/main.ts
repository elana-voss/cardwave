// The app's start: which screen an address shows (`screen`, made by the tabs, tabs.ts, each tab's its own; first
// run hides the rail and the tabs, `drawn`), one file per screen in views/; every tab's screen hears the server's
// events. `go` shows a new address in the tab in view, `open` a screen anew for a line of "Create". `start` restores
// the tabs per account (`tabs.restore`) once the server's first word is heard (`listen`; a screen made before it
// would read itself again then, redrawing its buttons under a click), and leads a start without an address to first
// run while `GET /api/provider` answers `null`; it waits `START_WAIT` at most for each. `before` is where first
// run's "Confirm" leads back to. The account's pages (`#/account`, `#/settings`) are one on the rail
// (`"account"`); account.ts hears a change of the account and asks again after a drop (`heard`). Where the server
// waits for the password, `start` shows the start screen (password.ts) alone, without the rail and the socket, and
// so the sign-in screen (accounts.ts, `GET /api/sign-in`); the app starts anew once unlocked, and when a backup was
// restored (`restored`). In the desktop app the companion's window (companion-app.ts) is told, by the app's window
// alone (`appWindow`), the tab in view; `#/companion` is the list of chats under the window that picks the
// companion; the app looks for a newer version (settings/update.ts). The user's own CSS (own-css.ts) shows before
// the first screen. The UI's words are in the settings' language, else the computer's (app-language.ts,
// language.ts); a change remakes the tabs' screens (`relanguage`). A phone's keyboard is followed (shell/keyboard.ts).
import { reread, setElsewhere, take } from "./account";
import { signInScreen } from "./settings/accounts";
import { companionApp, connectEvents, getLock, getProvider, getSettings, getSignIn, getStatus, startedSignedIn, unlock } from "./api/client";
import { appWindow, PAGE_WINDOW } from "./desktop";
import { clearNotice, type View } from "./dom";
import { followComputer, onLanguage, setSystem } from "./language/language";
import { restoredHeard, tellRestored } from "./settings/backup";
import { lockedElsewhere, passwordIs, startScreen, untilUnlocked } from "./settings/password";
import { pickCompanion, startCompanion } from "./library/companion-app";
import { readOwnCss } from "./settings/own-css";
import { readAppLanguage } from "./settings/app-language";
import { watchUpdates } from "./settings/update";
import { cardsReached } from "./setup/cards-step";
import { downloadsHeard, firstRunLeft, followDownloads, followsAtStart } from "./setup/downloads-step";
import { followKeyboard } from "./shell/keyboard";
import { makeRail } from "./shell/rail";
import { Tabs, type Tab } from "./shell/tabs";
import { makeTitleBar } from "./shell/titlebar";
import { remember, remembered } from "./storage";
import { showChatLayout, showMessagePictures } from "./theme";
import { advancedView } from "./views/advanced";
import { cssReferenceView } from "./views/css-reference";
import { aboutView } from "./views/about";
import { characterView, newCardView } from "./views/character";
import { chatView } from "./views/chat";
import { chatsView } from "./views/chats";
import { libraryView } from "./views/library";
import { lorebookView } from "./views/lorebook";
import { lorebooksView } from "./views/lorebooks";
import { memoriesView } from "./views/memories";
import { documentsView } from "./views/documents";
import { generatorView } from "./views/generator";
import { interviewView } from "./views/interview";
import { personasView } from "./views/personas";
import { profileView } from "./views/profile";
import { promptPresetView } from "./views/prompt-preset";
import { serverView } from "./views/server";
import { settingsView } from "./views/settings";
import { voicesView } from "./views/voices";
import { providersView } from "./views/providers";
import { setupView } from "./views/setup";
import { trashView } from "./views/trash";
import { writtenToolsView } from "./views/written-tools";
import { codingTeamView } from "./views/coding-team";
import { codingTaskView } from "./views/coding-task";
import { webPictures } from "./narration";

const main = document.querySelector<HTMLElement>("#view")!;

// Chats are drawn in the layout chosen, from the first one on.
showChatLayout();
showMessagePictures();

/** The address shown before first run, which leads back there when it is done. */
let before = "#/chats";

/** How long a start waits at most for the server's first word, and one without an address also for whether a provider
 * is stored, in milliseconds (each). */
const START_WAIT = 3000;

/**
 * Shows the screen at `address` anew, also where it is the one shown, and
 * answers with it: who leads to a screen has it do something at once. Where
 * another tab holds it, that tab shows, with its screen as it is.
 */
function open(address: string): View | null {
  // Setting the address tells of its change later; the screen is made now.
  if (location.hash !== address) history.pushState(null, "", address);
  tabs.go(address);
  return tabs.now().view;
}

const rail = makeRail(open, () => tabs.now().view);

/** What an address is under, as the rail calls it, and the part after it (of the chats a chat's number). */
function placeOf(address: string): { current: string; id: string | undefined } {
  const [, section, id] = address.split("/");
  const current = section === "library" || section === "settings" || section === "account" || section === "setup" || section === "knowledge" || section === "generator" || section === "interview" ? section : "chats";
  return { current, id };
}

/** Makes the screen the address names: `#/chats`, `#/chats/12`, `#/library`, `#/library/3`, `#/library/3/character/1`, `#/library/3/edit`, `#/library/3/edit/1`, `#/library/new`, `#/library/lorebooks`, `#/library/lorebooks/3`, `#/library/lorebooks/3/lore.x` (an entry by its reference, or `new`), `#/library/3/lorebook` (the card's own, its first; `#/library/3/lorebook.x` another), each with an entry after it as a library lorebook's, `#/library/personas`, `#/knowledge/memories`, `#/knowledge/documents`, `#/generator`, `#/interview`, `#/account/profile`, `#/account/server`, `#/settings`, `#/settings/trash`, `#/settings/advanced`, `#/settings/providers`, `#/settings/advanced/prompts/3` (a prompt preset, or `new`), `#/settings/advanced/css`, `#/settings/tools/written`, `#/settings/tools/coding`, `#/settings/about`, `#/settings/voices`, `#/chats/12/tasks/3` (a coding task), `#/setup`. */
function screen(address: string): View {
  const [, , id, part, of] = address.split("/");
  const { current } = placeOf(address);
  const number = (text: string | undefined) => (text && /^\d+$/.test(text) ? Number(text) : null);
  const numbered = number(id);
  if (current === "setup") return setupView(before);
  if (current === "settings") {
    // A prompt preset's editor is under "Advanced", `new` for one not made yet.
    const preset = id === "advanced" && part === "prompts" && (of === "new" || number(of) !== null);
    if (preset) return promptPresetView(number(of));
    if (id === "advanced" && part === "css") return cssReferenceView();
    if (id === "tools" && part === "written") return writtenToolsView();
    if (id === "tools" && part === "coding") return codingTeamView();
    if (id === "about") return aboutView();
    if (id === "providers") return providersView();
    if (id === "voices") return voicesView();
    return id === "trash" ? trashView() : id === "advanced" ? advancedView() : settingsView();
  }
  // Of the account's own pages there are the profile and the server.
  if (current === "account") return id === "server" ? serverView() : profileView();
  // Of Knowledge there are the memories and the documents.
  if (current === "knowledge") return id === "documents" ? documentsView() : memoriesView();
  if (current === "generator") return generatorView();
  if (current === "interview") return interviewView();
  if (current === "library") {
    if (id === "lorebooks") return number(part) === null ? lorebooksView() : lorebookView({ library: number(part)! });
    if (id === "personas") return personasView();
    if (id === "new") return newCardView();
    if (numbered === null) return libraryView();
    // A card's own lorebook: its first, or the one its reference names.
    if (part === "lorebook" || part?.startsWith("lorebook.")) return lorebookView({ card: numbered, book: part === "lorebook" ? undefined : decodeURIComponent(part) });
    // An old address of one of the card's characters, or of its editor, opens the card's page.
    return characterView(numbered);
  }
  if (numbered !== null && part === "tasks" && number(of) !== null) return codingTaskView(numbered, number(of)!);
  return numbered === null ? chatsView(open) : chatView(numbered);
}

/** The rail and the tabs, which first run and the start screen have not. */
function chrome(now: boolean): void {
  rail.show(now);
  bar.bare(!now);
}

/** Puts the tab in view's screen into the page, and marks where it is. */
function drawn(tab: Tab): void {
  const { current, id } = placeOf(tab.address);
  chrome(current !== "setup");
  clearNotice();
  main.replaceChildren(tab.view!.node);
  rail.mark(current === "settings" ? "account" : current, id);
  if (current !== "setup") before = tab.address;
}

/** The desktop app's window of one page ("Cardwave's CSS") has no tabs. */
const alone = window.cardwaveDesktop?.window === PAGE_WINDOW;
const tabs = new Tabs(screen, drawn, alone);
/** Where the page keeps whether it was signed in to another account than this computer's, for when the app is locked. */
const OTHER_ACCOUNT = "cardwave.other-account";
/** The computer's language in use: the start and sign-in screens, which no change of language redraws, wait for it. */
const computerLanguage = followComputer();
const bar = makeTitleBar(tabs, alone);
// The companion knows which screen Cardwave's window shows: its address and the name of its tab; a browser's page of
// the same user, or the window of one page, is not that window.
let screenSaid = "";
tabs.watch(() => {
  if (!appWindow()) return;
  const { address, title } = tabs.now();
  if (`${address} ${title}` === screenSaid) return;
  screenSaid = `${address} ${title}`;
  void companionApp({ route: address, title }).catch(() => {});
});

/**
 * Shows the first screen. A start without an address leads to first run while the user has no model provider. An
 * address that was asked for is shown as it is, and so is the list of chats when the server does not say, or not
 * within `START_WAIT`: the window does not stay empty for a server that hangs.
 */
async function start(): Promise<void> {
  // The font is there before the first screen is made, which is made after the server's answer: a screen made
  // before it came and one made after would differ (seen: a field's words a pixel lower, in some runs).
  const font = document.fonts.load(`16px ${getComputedStyle(document.body).fontFamily}`).catch(() => []);
  // The server's system is in the texts (paths, the bin) before the first screen is made.
  const system = getStatus().then(({ system }) => setSystem(system), () => undefined);
  const [lock, signing] = await Promise.all([getLock().catch(() => null), getSignIn().catch(() => null), font, computerLanguage, system]);
  if (lock?.locked) {
    chrome(false);
    // A device signed in to another account cannot open the app: its password is this computer's account's.
    const other = remembered(OTHER_ACCOUNT) === "1";
    main.replaceChildren(other ? lockedElsewhere() : startScreen(lock.name, (password) => unlock(password).then(() => location.reload())));
    // Unlocked elsewhere (on the computer, or another page), the page goes on by itself.
    untilUnlocked(getLock, () => location.reload());
    return;
  }
  passwordIs(lock?.password ?? false);
  setElsewhere(signing?.remote ?? false);
  if (signing?.needed) {
    chrome(false);
    main.replaceChildren(signInScreen(signing.accounts));
    return;
  }
  startedSignedIn();
  tellRestored();
  const current = signing?.accounts.find((one) => one.current);
  if (current) remember(OTHER_ACCOUNT, current.local ? "0" : "1");
  // The first screen is drawn with the user's own CSS, unless the server does not say within `START_WAIT`.
  const settings = getSettings();
  // The switch of pictures from the web as the page's policy was given (narration.ts).
  void settings.then(({ web_pictures }) => webPictures(web_pictures), () => {});
  readAppLanguage(settings);
  // The first screen is made once the server tells this page what happens: one made before would read itself again
  // at the server's first word, redrawing its buttons under a click (spec 65, "read once").
  const heard = listen();
  await Promise.race([Promise.all([readOwnCss(settings), heard]), new Promise((over) => setTimeout(over, START_WAIT))]);
  startCompanion();
  if (!alone) watchUpdates();
  const unasked = () => location.hash.length < 3;
  if (unasked()) {
    // The rail comes with the screen, as first run has none.
    chrome(false);
    const late = new Promise<undefined>((over) => setTimeout(over, START_WAIT));
    const provider = await Promise.race([getProvider().catch(() => undefined), late]);
    // First run's downloads not through yet come back to its last step; after "Open Cardwave" they go on outside it.
    const left = provider ? await Promise.race([settings.then((read) => read, () => undefined), late]) : undefined;
    // A start before first run ended, once it reached the folder of cards, comes back to it (models-step.ts `startStep`).
    const downloads = (!!left && firstRunLeft(left)) || (!!provider && cardsReached());
    if ((provider === null || downloads) && unasked()) history.replaceState(null, "", "#/setup");
  }
  // After "Open Cardwave" the downloads left go on at every start, one at a page's address (a reload) too.
  void settings.then((read) => followsAtStart(read, location.hash) && followDownloads(), () => undefined);
  window.addEventListener("hashchange", go);
  // The tabs of the start before, of this account, with the address asked for in the one in view.
  const account = current?.id;
  const restore = () => tabs.restore(account === undefined ? "tabs" : `tabs.${account}`, unasked() ? "" : location.hash);
  if (location.hash === "#/companion") companion(restore);
  else restore();
  onLanguage(() => tabs.relanguage());
}

/** `#/companion`: the list of chats, which `show` shows once the address is `#/chats`, under the window that picks the companion. */
function companion(show: () => void): void {
  history.replaceState(null, "", "#/chats");
  show();
  pickCompanion(main);
}

/**
 * Shows what the address names now in the tab in view (tabs.ts), or the tab
 * that holds it. `#/companion` is the list of chats under the window that
 * picks the companion.
 */
function go(): void {
  if (location.hash === "#/companion") return companion(() => tabs.go("#/chats"));
  tabs.go(location.hash);
  if (!location.hash.startsWith("#/setup")) before = location.hash;
}
followKeyboard();
void start();

/**
 * Has the server tell a screen what happens, and that it listens again after a drop; resolved at the server's first
 * word (`hello`), which it sends once it tells this page all that happens.
 */
function listen(): Promise<void> {
  let heard = false;
  let hello = () => {};
  const first = new Promise<void>((resolve) => (hello = resolve));
  connectEvents((event) => {
    if (event.type === "hello") hello();
    const views = tabs.list.map((tab) => tab.view);
    if (event.type === "hello") {
      for (const view of views) view?.onConnected?.();
      // After a drop the account may have another name, which was not heard, or none yet, where the start's asking failed.
      if (heard) {
        void reread();
        void readOwnCss();
        readAppLanguage();
      }
      heard = true;
    }
    // All the app holds is the backup's now.
    if (event.type === "restored") {
      restoredHeard();
      // First run starts anew as at an opening: the backup's provider, if it has one, opens the app.
      if (location.hash.startsWith("#/setup")) history.replaceState(null, "", location.pathname);
      location.reload();
    }
    if (event.type === "settings") {
      void readOwnCss();
      readAppLanguage();
    }
    // The account was changed, here or in another window: all that shows it is told.
    if (event.type === "account") take({ name: event.name, local: event.local, picture: event.picture });
    rail.heard(event);
    // The downloads first run left going after "Open Cardwave".
    downloadsHeard(event);
    // Every tab's screen hears it, the ones out of view too.
    for (const view of views) view?.onEvent?.(event);
  });
  return first;
}
