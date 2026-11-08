// What an import of files says. Several files have a panel at the window's
// foot: how far the import is, and a line per file that says what came of it.
// One file alone has the notice. The panel is the window's own, not a
// screen's: the import goes on, and says so, whatever screen is shown.
// What a file's import noted comes as codes and fields (cw-ccv4 note.rs), worded by `noteWords`.
//
// `fileImport` is the hidden field that asks for a section's files, with the drop on its page (`fileField` of
// dom.ts): what is picked
// or dropped is imported one file after the other, and what comes of it is said for several in the panel
// `#importing`, which stands before `#toast` in the page and stays over a change of screen, for one file
// alone in the notice; files join the import that runs, and the panel that still shows what it keeps
// (`kept`); for what has come the list is read anew on the screen made last for its kind (`lists`), at most
// every `LIST_EVERY` and once at the import's end; a file dragged or dropped anywhere else in the window is
// refused, as the window would show it in the app's place. A folder of cards' import, which the server runs, is
// followed in the same panel (`followFolderImport`); an import of files that runs keeps the panel until it is done.
import { getCardFolderImport } from "../api/client";
import type { FolderImport } from "../api/generated/FolderImport";
import type { ImportNote } from "../api/generated/ImportNote";
import { announce, closeButton, el, fileField, hasFiles, reason, toast } from "../dom";
import { icon, type IconName } from "../icons";
import { onLanguage, wording } from "../language/language";
import { failureWords } from "../language/errors";

/** A lorebook an imported card brings, which can be had in the library too. */
interface Offer {
  name: string;
  /** Copies it into the library, and answers with what it is called there. */
  copy(): Promise<string>;
}

/** What came of a file: what the new item is called, what the import has to say of it, and what it offers. */
export interface Came {
  title: string;
  warnings: ImportNote[];
  offers?: Offer[];
  /** Where what came is opened: the notice of one file alone offers it. */
  open?: string;
}

/** What the import says of a flaw of the file it took, in the page's language. */
export function noteWords(note: ImportNote): string {
  switch (note.code) {
    case "entries_not_a_list":
      return wording("import-note-entries-not-a-list");
    case "outlet_entries_off":
      return wording("import-note-outlet-entries-off", { count: note.count });
    case "asset_only_linked":
      return wording("import-note-asset-only-linked", { kind: note.kind || wording("import-note-asset"), name: note.name });
    case "asset_unreadable":
      return wording("import-note-asset-unreadable", { kind: note.kind || wording("import-note-asset"), name: note.name });
    case "unlisted_files":
      return wording("import-note-unlisted-files", { count: note.count });
    case "first_character_kept":
      return wording("import-note-first-character-kept", { name: note.name });
    case "misplaced":
      return wording("import-note-misplaced", { kind: note.kind, file: note.file });
    case "dangling":
      return wording("import-note-dangling", { owner: note.owner, key: note.key, reference: note.reference });
    case "unknown_placeholder":
      return wording("import-note-unknown-placeholder", { owner: note.owner, placeholder: note.placeholder });
    case "missing_asset":
      return wording("import-note-missing-asset", { owner: note.owner, key: note.key, file: note.file });
  }
}

/** What is imported. */
export type Kind = "card" | "lorebook";

/** What one of a kind is called, and several; files of two kinds are files. */

/** How long the panel stays when the import is done and it has nothing to keep, in milliseconds. */
const CLOSE_AFTER = 4000;

/**
 * While an import runs, the lists are read anew for what has come at most
 * this often, in milliseconds, and once more at its end: each reading is of a
 * whole list, and an import may be of a whole library.
 */
const LIST_EVERY = 1000;

/** A file of an import, and its line in the panel. */
interface Entry {
  kind: Kind;
  file: File;
  add(file: File): Promise<Came>;
  state: "waiting" | "importing" | "done" | "failed";
  /** What came of it, once it is done. */
  came?: Came;
  /** Its line, and the lines under it of the lorebooks it brings beyond the first. */
  nodes: HTMLElement[];
  /** Shows the line as the entry's state has it; of a file that failed it says `why`. */
  show(why?: string): void;
}

/** The files of the import that runs, or of the last one while its panel shows. */
let entries: Entry[] = [];
let running = false;
/** The wait after which the panel closes by itself. */
let closing = 0;
/**
 * What reads a kind's list anew, on the screen that shows it: the screen made
 * last says so, as an import outlives the screen it began on. It is told
 * whether this is the `first` time in the import that runs.
 */
const lists: Partial<Record<Kind, (first: boolean) => void>> = {};

const title = el("h2", { className: "semi" });
const close = closeButton(16);
const done = el("div");
const bar = el("div", { className: "bar f-none bg-fill", role: "progressbar", ariaLabel: wording("importing-imported") }, done);
const count = el("span", { className: "meta" });
const progress = el("div", { className: "import-progress flex f-col g-6" }, bar, count);
const lines = el("div", { className: "import-lines" });
const panel = el("div", { id: "importing", role: "status", ariaLabel: wording("create-import"), hidden: true }, el("div", { className: "import-head flex ai-c jc-sb" }, title, close), progress, lines);
// The labels drawn once, here, follow a change of language.
onLanguage(() => {
  bar.ariaLabel = wording("importing-imported");
  panel.ariaLabel = wording("create-import");
});

close.onclick = () => {
  panel.hidden = true;
  clearTimeout(closing);
};

/** So many of the kinds imported: "1 card", "3 lorebooks", "No files". */
function some(amount: number): string {
  const kinds = new Set(entries.map((entry) => entry.kind));
  return wording("importing-some", { kind: kinds.size === 1 ? entries[0].kind : "file", count: amount });
}

const having = (state: Entry["state"]) => entries.filter((entry) => entry.state === state).length;

/** A file that came with no more to say of it than the notice holds. */
const plain = (entry: Entry) => entry.state === "done" && !entry.came?.warnings.length && (entry.came?.offers?.length ?? 0) < 2;
/** A file the panel stays for until it is closed: one that failed, one the import says something of, one that brings a lorebook to copy. */
const kept = (entry: Entry) => !plain(entry) || Boolean(entry.came?.offers?.length);

/** The panel's head says how far the import is, or what it came to. */
function tell(): void {
  const [imported, failed] = [having("done"), having("failed")];
  const lost = failed ? wording("importing-failed", { failed }) : "";
  title.textContent = running ? wording("importing-importing", { some: some(entries.length) }) : wording("importing-imported-2", { some: some(imported), lost });
  progress.hidden = !running;
  done.style.width = `${((imported + failed) / entries.length) * 100}%`;
  bar.ariaValueMin = "0";
  bar.ariaValueMax = String(entries.length);
  bar.ariaValueNow = String(imported + failed);
  count.textContent = wording("importing-of", { imported: imported + failed, count: entries.length, lost });
}

/** A line's parts: the mark of its state, a name, what is said under it, and the place of its button. */
function line(name: string) {
  const mark = el("span", { className: "import-mark flex" });
  const called = el("span", { className: "import-name medium" }, name);
  const said = el("span", { className: "meta" });
  const slot = el("span", { className: "import-slot flex f-none" });
  const node = el("div", { className: "import-line item item-line g-10" }, mark, el("div", { className: "item-text" }, called, said), slot);
  /** Cuts what is said where the line ends, with the button that shows it in full. */
  const whole = (label: string) => {
    const button = el("button", { type: "button", className: "btn btn-quiet btn-fit", ariaExpanded: "false" }, label);
    button.onclick = () => (button.ariaExpanded = String(!said.classList.toggle("ellipsis")));
    said.classList.add("ellipsis");
    slot.replaceChildren(button);
  };
  return { node, mark, called, said, slot, whole };
}

/** Says of a lorebook a card brings that it can be had in the library, in `said`, with the button that copies it there in `slot`. */
function offering(offer: Offer, said: HTMLElement, slot: HTMLElement): void {
  said.textContent = wording("importing-brings-a-lorebook", { name: offer.name });
  const copy = el("button", { type: "button", className: "btn btn-secondary btn-fit" }, wording("card-box-copy-to-library"));
  copy.onclick = async () => {
    copy.disabled = true;
    try {
      const made = await offer.copy();
      said.classList.remove("c-danger");
      said.textContent = wording("importing-in-the-library-as", { made });
      copy.remove();
    } catch (error) {
      // It can be tried again.
      said.classList.add("c-danger");
      said.textContent = reason(error);
      copy.disabled = false;
    }
  };
  slot.replaceChildren(copy);
}

const marks = (): Record<Entry["state"], [IconName, string]> => ({
  waiting: ["clock", wording("setup-waiting")],
  importing: ["clock", wording("importing-importing-2")],
  done: ["check", wording("importing-imported")],
  failed: ["close", ""],
});

/** Makes a file's entry, which waits for its turn. */
function entryOf(kind: Kind, file: File, add: Entry["add"]): Entry {
  const { node, mark, called, said, slot, whole } = line(file.name);
  const entry: Entry = { kind, file, add, state: "waiting", nodes: [node], show };
  function show(why = ""): void {
    const [shape, says] = marks()[entry.state];
    mark.replaceChildren(icon(shape, 16));
    mark.className = `import-mark flex ${entry.state}`;
    said.textContent = says || why;
    if (entry.state === "failed") whole(wording("importing-why"));
    if (!entry.came) return;
    const { title: name, warnings, offers = [] } = entry.came;
    called.textContent = name;
    // What the import has to say of it takes the line; else the first lorebook it brings does. Each other has a line of its own.
    const others = warnings.length ? offers : offers.slice(1);
    if (warnings.length) {
      said.textContent = warnings.map(noteWords).join(" ");
      whole(wording("character-details"));
    } else if (offers.length) {
      offering(offers[0], said, slot);
    }
    for (const offer of others) {
      const more = line("");
      more.called.remove();
      offering(offer, more.said, more.slot);
      entry.nodes[entry.nodes.length - 1].after(more.node);
      entry.nodes.push(more.node);
    }
  }
  show();
  return entry;
}

/** Imports the files that wait, one after the other, and says what the import came to. */
async function run(): Promise<void> {
  if (running) return tell();
  running = true;
  /** The kinds of which something has come that no list was read for yet, those a list was read for, and when. */
  const came = new Set<Kind>();
  const listed = new Set<Kind>();
  let read = -Infinity;
  const list = () => {
    for (const kind of came) {
      lists[kind]?.(!listed.has(kind));
      listed.add(kind);
    }
    came.clear();
    read = performance.now();
  };
  for (let next; (next = entries.find((entry) => entry.state === "waiting")); ) {
    next.state = "importing";
    next.show();
    tell();
    let why = "";
    try {
      next.came = await next.add(next.file);
      next.state = "done";
      came.add(next.kind);
    } catch (error) {
      next.state = "failed";
      why = reason(error);
    }
    next.show(why);
    if (performance.now() - read >= LIST_EVERY) list();
  }
  list();
  running = false;
  const [only] = entries;
  // One file alone, with no more to say of it than the notice holds, has the notice alone.
  if (entries.length === 1 && plain(only)) {
    const [offer] = only.came?.offers ?? [];
    const copy = offer && (async () => announce(wording("importing-the-lorebook-is-in", { copy: await offer.copy() })));
    const title = only.came?.title ?? "";
    const open = only.came?.open;
    if (offer) announce(wording("importing-one-with-lorebook", { title, name: offer.name }), copy, false, wording("card-box-copy-to-library"));
    else if (open) announce(wording("importing-one", { title }), async () => void (location.hash = open), false, wording("importing-open"));
    else announce(wording("importing-one", { title }));
    return;
  }
  tell();
  // With something to keep it stays until it is closed, and comes back if it was closed while the import ran. Else
  // it goes by itself.
  if (entries.some(kept)) panel.hidden = false;
  else closing = window.setTimeout(() => (panel.hidden = true), CLOSE_AFTER);
}

/**
 * Imports `files` as items of a `kind`, one after the other, each with `add`,
 * which answers with what came of it. Several files, and files that join an
 * import that runs, show the panel; one file alone shows it only where the
 * notice cannot hold what there is to say: it failed, the import has
 * something to say of it, or it brings several lorebooks.
 */
function importFiles(kind: Kind, files: File[], add: Entry["add"]): void {
  if (!files.length) return;
  clearTimeout(closing);
  // A new import begins with a panel of its own lines. Files join the import that runs, and the panel that still
  // shows what it keeps: that stays until it is closed.
  if (!running && (panel.hidden || !entries.some(kept))) {
    entries = [];
    lines.replaceChildren();
  }
  // The files have the panel now; a folder's import that goes on takes it again once they are done.
  folderShown = -1;
  for (const file of files) {
    const entry = entryOf(kind, file, add);
    entries.push(entry);
    lines.append(...entry.nodes);
  }
  // The panel lies under the notice, which comes and goes.
  if (!panel.isConnected) toast().before(panel);
  panel.hidden = entries.length === 1;
  void run();
}

/** What the head says of a folder's import: its title, and under the bar how far it is. */
export function folderSaid({ running, found, imported, skipped, failed }: FolderImport): { title: string; count: string } {
  const cards = (count: number) => wording("importing-some", { kind: "card", count });
  const lost = failed.length ? wording("importing-failed-2", { count: failed.length }) : "";
  if (running && !found) return { title: wording("importing-importing-cards"), count: wording("importing-looking-for-card-files") };
  if (running) return { title: wording("importing-importing-3", { cards: cards(found) }), count: wording("importing-done-of", { done: imported + skipped + failed.length, found, lost }) };
  const had = skipped ? wording("importing-already-in-the-library", { skipped }) : "";
  return { title: wording("importing-imported-3", { cards: cards(imported), had, lost }), count: "" };
}

/** Whether the panel follows a folder's import, which a second start then leaves to it. */
let following = false;
/** How many of the folder's failed files have their line in the panel; -1 while the panel is not the folder's. */
let folderShown = -1;

/** Shows a folder's import in the panel: the head, the bar, and a line for each file that failed not shown yet. */
function showFolder(state: FolderImport): void {
  // An import of files that runs has the panel; the folder's takes it at its next asking after it, keeping the
  // files' lines that are to stay.
  if (running) return;
  if (folderShown < 0) {
    if (!entries.some(kept)) lines.replaceChildren();
    entries = [];
    folderShown = 0;
    clearTimeout(closing);
    if (!panel.isConnected) toast().before(panel);
    panel.hidden = false;
  }
  const { title: said, count: far } = folderSaid(state);
  const handled = state.imported + state.skipped + state.failed.length;
  title.textContent = said;
  count.textContent = far;
  progress.hidden = !state.running;
  done.style.width = `${state.found ? (handled / state.found) * 100 : 0}%`;
  bar.ariaValueMin = "0";
  bar.ariaValueMax = String(state.found);
  bar.ariaValueNow = String(handled);
  for (const file of state.failed.slice(folderShown)) {
    const { node, mark, said: why, whole } = line(file.name);
    mark.replaceChildren(icon("close", 16));
    mark.className = "import-mark flex failed";
    why.textContent = failureWords(file.reason);
    whole(wording("importing-why"));
    lines.append(node);
  }
  folderShown = state.failed.length;
}

/**
 * Shows the import of a folder of cards that the server runs in the panel,
 * asking how far it is every `LIST_EVERY` until it ends (the screens read
 * their lists on the server's `card_folder`). The panel then stays where a
 * file failed, with a line for each, and else goes by itself.
 */
export async function followFolderImport(): Promise<void> {
  if (following) return;
  following = true;
  folderShown = -1;
  let last: FolderImport | null = null;
  for (;;) {
    try {
      last = await getCardFolderImport();
    } catch {
      // The server was not heard this time: it is asked again.
      await new Promise((wait) => setTimeout(wait, LIST_EVERY));
      continue;
    }
    if (last) showFolder(last);
    // None since the server started: it was started anew, and the import with it is over.
    if (!last?.running) break;
    await new Promise((wait) => setTimeout(wait, LIST_EVERY));
  }
  // What it came to is shown once an import of files that runs is done.
  while (last && running) await new Promise((wait) => setTimeout(wait, LIST_EVERY));
  if (last) showFolder(last);
  following = false;
  if (last && !lines.children.length) closing = window.setTimeout(() => (panel.hidden = true), CLOSE_AFTER);
}

/**
 * The field that asks for files of a `kind` to import, which stands hidden in
 * a section's `page`. Files picked in it and files dropped on the page are
 * imported, each with `add`, and `added` reads the page's list anew for what
 * has come, while the page is the one shown: it is told whether it is the
 * `first` time for the import that runs.
 */
export function fileImport(kind: Kind, accept: string, page: HTMLElement, add: Entry["add"], added: (first: boolean) => void): HTMLInputElement {
  const field = fileField(page, accept, true, (files) => importFiles(kind, files, add));
  page.append(field);
  lists[kind] = (first) => page.isConnected && added(first);
  return field;
}

// A file dropped anywhere else is taken by nothing. Left to itself, the window would show the file in the app's place.
window.addEventListener("dragover", (event) => {
  if (event.defaultPrevented || !hasFiles(event)) return;
  event.preventDefault();
  event.dataTransfer!.dropEffect = "none";
});
window.addEventListener("drop", (event) => {
  if (hasFiles(event)) event.preventDefault();
});
