// The library's personas: who the user can be in a chat. They are searched
// (no Favourites or Archived: a user has two or three), made and changed in place, and one of them is the default. A row has the persona's picture or
// its initial; on touch a tap on it opens its form, as no button shows there. A change in another window has the
// list read anew, around a form that is open.
//
// A form opened as soon as the screen is made (Create > New persona) is there before the list, and the list,
// when it comes, is drawn around it: a field that had the focus loses it unless it is given back (`draw`).
import { changePersona, createPersona, libraryLorebooks, listPersonas, setPersonaPicture } from "../api/client";
import type { ChangePersona } from "../api/generated/ChangePersona";
import type { Persona } from "../api/generated/Persona";
import { announce, el, TOUCH, type View } from "../dom";
import { smallPicture } from "../art";
import { menu, type MenuItem } from "../dialogs";
import { initialOf } from "../format";
import { icon } from "../icons";
import { deleteLine, undoable } from "../library/library-actions";
import { type Asked, emptyLine, keyed, listScreen, readList } from "../library/list-screen";
import { personaForm, type PersonaSave } from "../library/persona-form";
import { wording } from "../language/language";

/** What the list was last asked for. Kept while the app runs, so coming back shows the same list. */
const asked: Asked = { q: "", show: "all" };
/** What the list says when no persona was ever made. */
const noPersonas = () => (wording("personas-no-personas-yet-a"));

/** A persona's line: its picture or letter, name, whether new chats start as it, its description, and at the side "Edit" and the menu `lines`. */
function personaRow(persona: Persona, lines: MenuItem[], edit: () => void): HTMLElement {
  return el(
    "li",
    { className: "item row item-roomy ai-s card-row" },
    el("span", { className: "initial", ariaHidden: "true" }, persona.picture ? el("img", { src: persona.picture, alt: "" }) : initialOf(persona.name)),
    el(
      "div",
      { className: "item-text item-text-spaced" },
      el(
        "div",
        { className: "row-head flex ai-b g-8 wrap" },
        el("span", { className: "row-title ttl" }, persona.name),
        persona.is_default && el("span", { className: "meta" }, wording("panel-persona-default")),
      ),
      persona.description && el("p", { className: "excerpt two-lines" }, persona.description),
    ),
    el(
      "div",
      { className: "flex ai-c g-4 f-none" },
      el("div", { className: "reveal flex g-4" }, el("button", { type: "button", className: "btn btn-secondary wide-only", onclick: edit }, icon("edit", 16), wording("common-edit")), menu(wording("common-more"), lines)),
    ),
  );
}

export function personasView(): View {
  /** The personas last read, and what to say when there are none. */
  let personas: Persona[] = [];
  let none = "";
  const { node, tools, list, attempt, load } = listScreen({
    title: wording("page-personas"),
    kind: "library",
    search: wording("personas-search-personas"),
    placeholder: wording("personas-name-or-description"),
    unread: wording("personas-couldnt-load"),
    asked,
    plain: true,
    // Personas are searched only and have no archive: what the list asks for beside the words is not sent.
    read: () => readList(({ q }) => listPersonas({ q }), wording("list-screen-personas"), asked, noPersonas(), "", false),
    show: ([found, empty]) => {
      [personas, none] = [found, empty];
      draw();
    },
  });
  /**
   * The form that is open, and whose it is: a persona's, or `null` for a new
   * one. It is kept while the list is drawn anew, with what was typed into it.
   */
  let open: { id: number | null; row: HTMLElement } | null = null;

  function draw(): void {
    // The form of a persona the list no longer shows is closed.
    if (open && open.id !== null && !personas.some((persona) => persona.id === open?.id)) open = null;
    const rows = personas.map((persona) => keyed(open?.id === persona.id ? open.row : row(persona), persona.id));
    if (open?.id === null) rows.unshift(open.row);
    // The form keeps the focus while the list is drawn anew around it: "Create" opens it before the list has come.
    const held = open?.row.contains(document.activeElement) ? (document.activeElement as HTMLElement) : null;
    list.replaceChildren(...rows);
    held?.focus();
    if (none && !open) list.append(emptyLine(none, none === noPersonas() ? [{ label: wording("create-new-persona"), go: () => edit() }] : []));
  }

  /** Opens the form in a persona's place, or for a new one on top of the list. Another one that was open is closed. */
  function edit(persona?: Persona): void {
    const save: PersonaSave = (name, description, picture, lorebooks) =>
      attempt(async () => {
        const small = picture && (await smallPicture(picture));
        if (persona) {
          await changePersona(persona.id, { name, description, lorebooks });
          if (small !== undefined) await setPersonaPicture(persona.id, small);
          return;
        }
        const made = await createPersona({ name, description, lorebooks });
        if (small) await setPersonaPicture(made.id, small);
        // A new persona is in view at once, whatever the list was searched or filtered for.
        tools.showAll();
        announce(wording("personas-added", { name: made.name }));
      }, persona?.name);
    const close = () => {
      open = null;
      void load();
    };
    const form = personaForm(save, close, libraryLorebooks(), persona);
    open = { id: persona?.id ?? null, row: el("li", null, form.node) };
    draw();
    form.name.focus();
  }

  function row(persona: Persona): HTMLElement {
    const act = (action: () => Promise<void>) => attempt(action, persona.name);
    const change = async (to: ChangePersona) => {
      await changePersona(persona.id, to);
      await load();
    };
    const put = undoable(persona.name, act, change);
    const makeDefault = (now: boolean) =>
      act(async () => {
        await change({ is_default: now });
        announce(now ? wording("personas-new-chats-start-as", { name: persona.name }) : wording("personas-new-chats-start-without"));
      });
    const lines: MenuItem[] = [deleteLine(put)];
    if (persona.is_default) lines.unshift({ label: wording("personas-remove-as-default"), shape: "default", action: () => makeDefault(false) });
    else lines.unshift({ label: wording("personas-set-as-default"), shape: "default", action: () => makeDefault(true) });
    // A narrow window has no room for the button beside the words: there the menu begins with it.
    lines.unshift({ label: wording("common-edit"), shape: "edit", narrow: true, action: () => edit(persona) });
    const shown = personaRow(persona, lines, () => edit(persona));
    // On touch the row's buttons do not show: a tap on the row opens its form.
    shown.onclick = (event) => {
      if (TOUCH.matches && !(event.target as Element).closest("button, a, input")) edit(persona);
    };
    return shown;
  }

  void load();
  // "Create" leads here for a new persona. A change in another window shows; the form that is open stays, with what was typed.
  return { node: node, create: () => edit(), onEvent: (event) => void (event.type === "personas" && load()), onConnected: () => void load() };
}
