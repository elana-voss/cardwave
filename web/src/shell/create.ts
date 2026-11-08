// "Create": the menu of what is made, and under a rule what is brought in, from any screen.
//
// `createMenu` is the menu of `createItems`: a line that imports or makes something has `open` of main.ts show
// its screen anew and calls that screen's `View.create`. "New character" is the one way to make a character: its
// page offers the generator and "Make a character together" (card/card-ways.ts).
// `newChat` is its line "New chat", `plainChat` its "Chat without a character"; "New lorebook" opens its window over the screen shown, as "New chat" does
// (`shown`), and the editor of the lorebook made is shown after it. `freshStart` is the same lines in the empty
// main area while nothing exists (board "Fresh start"), in two groups, New and Import. Its words are language.ts's,
// read each time the lines are made.
import { newChatDialog } from "../library/add-character";
import { characterWays } from "../library/list-screen";
import { announce, el, reason, type View } from "../dom";
import { menuOn, type MenuItem } from "../dialogs";
import { icon } from "../icons";
import { wording } from "../language/language";
import { beginChat } from "../library/library-actions";
import { newLorebook } from "../lorebook/lorebook-dialog";

/** The screen that is shown, for a window over it; the page's place where there is none. */
function shown(): HTMLElement {
  const page = document.querySelector<HTMLElement>("#view")!;
  return (page.firstElementChild as HTMLElement | null) ?? page;
}

/**
 * Opens the window "New chat" over the screen that is shown: the characters picked start a chat, each with its
 * card's newest version, which is shown, the user as the persona the window picked (`null`: the default). Why it could
 * not the window says. While the library has no character, the window offers New character and Import card instead.
 */
function newChat(open: (address: string) => View | null): void {
  const lead = (address: string) => () => open(address)?.create?.();
  newChatDialog(
    shown(),
    (picks, persona) =>
      beginChat(
        picks.map((pick) => ({ version_id: pick.versionId, character: pick.character })),
        undefined,
        persona ?? undefined,
      ),
    characterWays(lead("#/library/new"), lead("#/library")),
  );
}

/** Starts a chat without a character, the AI itself, and shows it. Why it could not the notice says. */
function plainChat(): void {
  beginChat([]).catch((error: unknown) => announce(reason(error)));
}

/**
 * Create's lines, what is made and under a rule (`apart`) what is brought in. A line that imports or makes
 * something leads to the screen that does so, which `open` shows and answers with, and has it begin at once:
 * the library's sections ask for the files, the personas open the form for a new one. A new card has a form of
 * its own as its screen.
 */
function createItems(open: (address: string) => View | null): MenuItem[] {
  const lead = (address: string) => () => open(address)?.create?.();
  return [
    { label: wording("create-new-chat"), shape: "chat", action: () => newChat(open) },
    { label: wording("create-plain-chat"), shape: "robot", action: plainChat },
    { label: wording("create-new-card"), shape: "edit", action: lead("#/library/new") },
    { label: wording("create-new-persona"), shape: "persona", action: lead("#/library/personas") },
    { label: wording("create-new-lorebook"), shape: "lorebook", action: () => newLorebook(shown()) },
    { label: wording("create-import-card"), shape: "import", apart: true, action: lead("#/library") },
    { label: wording("create-import-lorebook"), shape: "import", action: lead("#/library/lorebooks") },
  ];
}

/** Gives `button` the menu "Create". The menu places itself, as the rail would cut it off. */
export function createMenu(button: HTMLButtonElement, open: (address: string) => View | null): HTMLElement {
  return menuOn(button, createItems(open), true);
}

/** Create's lines in the empty main area, while nothing exists: a grey box of what is made, and one of what is brought in, each line with its icon. */
export function freshStart(open: (address: string) => View | null): HTMLElement {
  const items = createItems(open);
  const at = items.findIndex((item) => item.apart);
  const group = (label: string, part: MenuItem[]) =>
    el("div", null, el("p", { className: "cap" }, label), el("div", { className: "lst", role: "group", ariaLabel: label }, ...part.map((item) => el("button", { type: "button", onclick: () => item.action() }, icon(item.shape!), item.label))));
  return el("div", { className: "fresh flex ai-s wrap" }, group(wording("create-new"), items.slice(0, at)), group(wording("create-import"), items.slice(at)));
}
