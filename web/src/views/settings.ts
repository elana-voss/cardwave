// Account settings, at `#/settings`, what is often changed (the split into basic and advanced, milestone 70):
// the groups Appearance (theme and chat layout, this browser's own; "Show pictures from other websites", the server's; in the
// desktop app the companion and its figure, companion-app.ts), Language (the app's, the AI's), Models (the line to
// Providers, Chat, Images, Voice, Search and Dictation; ../models/models-group.ts), Tools (tools.ts), Data (Trash, Backup and
// Restore, backup.ts; the folder of cards, card-folder.ts) and the last box: "Advanced" (advanced.ts, which holds the rest), in the desktop app
// "Check for updates" and "Check automatically" (update.ts), "Run setup again" (first run, `#/setup`) and "About Cardwave" (about.ts). Its bar has the account's tabs.
//
// Another account than this computer's has no Backup, no Restore and no folder of cards in Data, as they are the
// database's and this computer's. A line of a
// group is `item` of dom.ts. Traps: `getProvider` of api/client.ts answers after a store that is on its way, so
// this page and "Advanced" each show what the other stored. A store made in another window (the event
// `provider`), and the server heard again after a drop, have Models and its line to Providers read anew; so do the settings changed in
// another window (the event `settings`) every line that shows one, and the Trash changed its line in Data.
import { wording } from "../language/language";
import { getLock, getSettings, getStatus, getTrash } from "../api/client";
import type { EntryView } from "../api/generated/EntryView";
import type { ProvidersView } from "../api/generated/ProvidersView";
import { backupLine } from "../settings/backup";
import { cardFolderLines } from "../settings/card-folder";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { aboutChoice, el, group, item, link, noticeBox, oneAtATime, segmented, selectField, type View } from "../dom";
import { modelsGroup } from "../models/models-group";
import { lineFiller, settingSwitch } from "../settings/setting-lines";
import { account } from "../account";
import { accountTabs } from "../shell/account-tabs";
import { dictationLine } from "../voice/dictation-setup";
import { searchLine } from "../models/search-setup";
import { companionLine, figureLine, sizeLine } from "../library/companion-app";
import { languageLine } from "../models/language-line";
import { providerName } from "../models/kinds";
import { appLanguageLine } from "../settings/app-language";
import { toolsGroup } from "../settings/tools";
import { updateLines } from "../settings/update";
import { voiceLine } from "../voice/voice-setup";
import { chatLayouts, chatLayout, LOOK, setChatLayout, setTheme, theme, themes, type Theme } from "../theme";
import { LABELS } from "../setting-labels";
import { comma } from "../format";

/**
 * The group "Appearance": the theme, which is the system's until light or dark is picked, and how a chat draws
 * its messages, as bubbles until plain is picked, both this browser's own; and "Show pictures from other websites", the
 * server's, off until switched on (the owner, 2026-10-21; narration.ts).
 */
function appearanceGroup(): { node: HTMLElement; read(): void; left(): void } {
  // Theme and Chat layout show what was chosen, also in the title bar's view menu, until the page is left; a
  // choice pressed here marks itself, and redrawing then would drop the pressed pill's focus. The theme is a select
  // field, its eight choices too many for pills (Claude, 2026-11-06), which keeps its own focus.
  const themeField = selectField(themes().map(([value, label]) => ({ value, label })), theme(), (to) => setTheme(to as Theme), { ariaLabel: LABELS.settings.theme });
  const layouts = () => segmented(LABELS.settings.chatLayout, chatLayouts(), chatLayout(), setChatLayout);
  let layoutNode = layouts();
  const themeAbout = el("span", { className: "meta" });
  const sayTheme = () => (themeAbout.textContent = aboutChoice(theme() !== "system", wording("settings-theme-about")));
  sayTheme();
  const watching = new AbortController();
  document.addEventListener(LOOK, () => {
    themeField.value = theme();
    sayTheme();
    if (layoutNode.contains(document.activeElement)) return;
    layoutNode.replaceWith((layoutNode = layouts()));
  }, { signal: watching.signal });
  const companion = companionLine();
  const figure = figureLine();
  const size = figure && sizeLine(figure.notice);
  const notice = noticeBox();
  const web = settingSwitch(oneAtATime(notice), LABELS.settings.webPictures, "web_pictures");
  const fill = lineFiller(notice);
  const node = group(
    wording("settings-appearance"),
    null,
    notice,
    figure?.notice ?? null,
    el(
      "div",
      { className: "group" },
      item(LABELS.settings.theme, themeAbout, themeField.node),
      item(LABELS.settings.chatLayout, wording("settings-layout-about"), layoutNode),
      item(LABELS.settings.webPictures, wording("settings-web-pictures-about"), web.toggle),
      companion?.node ?? null,
      figure?.node ?? null,
      size?.node ?? null,
    ),
  );
  const read = () => {
    companion?.read();
    figure?.read();
    size?.read();
    fill(getSettings, web.show);
  };
  read();
  return { node, read, left: () => watching.abort() };
}

/**
 * The group "Language": the language of the app (app-language.ts), then the language the AI writes in, which follows
 * it until changed. A chat uses a card in it where the card has it, and its replies are asked in it (chats/inputs.rs).
 */
function languageGroup(): { node: HTMLElement; read(): void } {
  const app = appLanguageLine();
  const line = languageLine();
  const node = group(wording("settings-language"), null, app.notice, line.notice, el("div", { className: "group" }, app.node, line.node));
  return { node, read: line.read };
}

/**
 * The group "Data": the way to the Trash, then Backup and Restore (backup.ts), then the folder of cards
 * (card-folder.ts); what Export writes is Settings › Advanced's.
 */
function dataGroup(home: () => HTMLElement): { node: HTMLElement; readTrash(): void; read(): void } {
  const notice = noticeBox();
  const backup = backupLine(home);
  const cards = cardFolderLines(home, oneAtATime(notice));
  // The database's backup is this computer's account's. The password is Profile's alone (the owner, 2026-10-15).
  for (const line of backup.nodes) line.hidden = true;
  void account().then(({ local }) => backup.nodes.forEach((line) => (line.hidden = !local)), () => {});
  const inTrash = el("span", { className: "meta" });
  const fill = lineFiller(notice);
  const readTrash = () =>
    fill(getTrash, ({ days, items }) => {
      inTrash.textContent = wording("settings-trash-about", { count: items.length, days });
    });
  readTrash();
  fill(getLock, ({ password: on }) => backup.show(on));
  const read = () => void fill(getSettings, cards.show);
  read();
  const node = group(
    wording("settings-data"),
    null,
    notice,
    el(
      "div",
      { className: "group" },
      item(
        el("span", { className: "item-label" }, LABELS.settings.trash),
        inTrash,
        el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("settings-open-trash"), onclick: () => (location.hash = "#/settings/trash") }, wording("settings-open")),
      ),
      ...backup.nodes,
      ...cards.nodes,
    ),
  );
  return { node, readTrash: () => void readTrash(), read };
}

/**
 * The last box: a line that is a link to the page "Advanced", which names what that page has; one to the page
 * "About Cardwave", with the version; between them, in the desktop app "Check for updates" and "Check
 * automatically" (update.ts), and
 * "Run setup again", which opens first run.
 */
function advancedGroup(home: () => HTMLElement): HTMLElement {
  const version = el("span", { className: "meta" });
  void getStatus()
    .then((status) => (version.textContent = wording("settings-version", { version: status.version })))
    .catch(() => (version.textContent = wording("settings-licences")));
  const updates = updateLines(home);
  return group(
    null,
    null,
    updates?.notice ?? null,
    el(
      "div",
      { className: "group" },
      link("#/settings/advanced", LABELS.settings.advanced, wording("settings-advanced-about")),
      ...(updates?.lines ?? []),
      link("#/setup", LABELS.settings.setup, wording("settings-setup-about")),
      link("#/settings/about", LABELS.settings.about, version),
    ),
  );
}

/** Providers' grey line: "Set up: [their names]", this computer's as "this computer"; without one, what the page is for. */
export function providersSaid(providers: EntryView[]): string {
  if (!providers.length) return wording("settings-providers-about");
  const names = providers.map((provider) => (provider.folder !== null ? wording("settings-this-computer") : providerName(provider.name)));
  return wording("settings-providers-named", { names: names.join(comma()) });
}

/** The line to Providers, told each list Models reads; until then, and where none is read, it says what the page is for. */
function providersLine(): { node: HTMLElement; say(list: ProvidersView): void } {
  const says = el("span", { className: "meta" }, providersSaid([]));
  const node = link("#/settings/providers", LABELS.settings.providers, says);
  return { node, say: (list) => (says.textContent = providersSaid(list.providers)) };
}

export function settingsView(): View {
  const node = el("section", { className: "main" });
  const voice = voiceLine(() => node);
  const search = searchLine(() => node);
  const dictation = dictationLine(() => node);
  const providers = providersLine();
  const models = modelsGroup({
    title: wording("settings-models"),
    lead: [providers.node],
    onList: providers.say,
    kinds: [
      ["chat", wording("settings-the-chat-model")],
      ["images", wording("settings-the-image-model")],
    ],
    more: [
      { ...voice, kind: "voice" },
      { ...search, kind: "search" },
    ],
    foot: [dictation.node],
  });
  const tools = toolsGroup(() => node);
  const [appearance, language, data] = [appearanceGroup(), languageGroup(), dataGroup(() => node)];
  const tabs = accountTabs("#/settings");
  node.append(
    tabs.node,
    el("div", { className: "page-col" }, appearance.node, language.node, models.node, tools.node, data.node, advancedGroup(() => node)),
  );
  /** Every line that shows a setting reads it anew. */
  const settled = () => {
    for (const group of [appearance, language, tools, voice, data]) group.read();
  };
  return {
    node: node,
    // What was stored in another window, and what may have been stored while the server was not heard.
    onEvent: (event: ServerEvent) => {
      if (event.type === "provider") models.read();
      if (event.type === "search") search.read();
      if (event.type === "dictation") dictation.read();
      if (event.type === "voice") voice.read();
      if (event.type === "settings") settled();
      if (event.type === "trash") data.readTrash();
    },
    onConnected: () => {
      settled();
      models.read();
      search.read();
      dictation.read();
      data.readTrash();
    },
    left: () => {
      tabs.left();
      appearance.left();
    },
  };
}
