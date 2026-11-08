// The form a persona is made or changed with: its picture at the top ("Add picture", then "Change" and
// "Remove", the round showing the picture or the initial), its name, its description and its lorebooks, a grey
// box as a card's page has (`lorebooksBox`): those of the library given to it, which every chat it is in has, each
// with its ×, and "+" with those of the library it has not. The picture and the lorebooks are kept with "Save", as
// the rest is: `save` is given the file picked, `null` where it was removed, or nothing, and the lorebooks' IDs
// where they were changed, or nothing, so that a save of the name keeps what another window gave meanwhile.
import type { Lorebook } from "../api/generated/Lorebook";
import type { Persona } from "../api/generated/Persona";
import type { PersonaLorebook } from "../api/generated/PersonaLorebook";
import { el, fileField, lineButton } from "../dom";
import { PICTURES } from "../art";
import { initialOf } from "../format";
import { addLorebookMenu, lorebookRow } from "./library-actions";
import { wording } from "../language/language";

/** What the form saves: the name, the description, the picture and the lorebooks' IDs (see the head). */
export type PersonaSave = (name: string, description: string, picture: File | null | undefined, lorebooks: number[] | undefined) => Promise<boolean>;

/**
 * The box of the persona's lorebooks, which begins with `given`; `library`, once it is read, is what "+"
 * offers. Answers the box and the lorebooks it holds as they then are, where they are not `given`.
 */
function lorebooksBox(given: PersonaLorebook[], library: Promise<Lorebook[]>): { node: HTMLElement; held(): number[] | undefined } {
  let held = [...given];
  let offered: Lorebook[] = [];
  const add = el("div", { className: "add-place" });
  const list = el("ul", { className: "rows-plain" });
  const none = el("p", { className: "hint" }, wording("persona-form-none-yet"));
  const draw = (focus?: string) => {
    list.replaceChildren(
      ...held.map((book) =>
        lorebookRow(
          book.name,
          book.trashed,
          lineButton(wording("persona-form-remove-from-this-persona-2", { name: book.name }), wording("persona-form-remove-from-this-persona"), "close", () => {
            held = held.filter((one) => one.id !== book.id);
            draw(wording("library-actions-add-lorebook"));
          }),
        ),
      ),
    );
    list.hidden = held.length === 0;
    none.hidden = !list.hidden;
    const toTake = offered.filter((lorebook) => !held.some((one) => one.id === lorebook.id));
    add.replaceChildren(
      addLorebookMenu(toTake, (lorebook) => {
        held = [...held, { id: lorebook.id, name: lorebook.name, trashed: false }];
        draw(wording("library-actions-add-lorebook"));
      }),
    );
    if (focus) add.querySelector("button")?.focus();
  };
  void library.then((read) => {
    offered = read;
    draw();
  }, () => undefined);
  draw();
  // The grey line stands under the box (board "Library · Personas", v5).
  const node = el(
    "div",
    { className: "persona-lorebooks fld" },
    el("div", { className: "box gbox" }, el("div", { className: "box-part part" }, el("div", { className: "bhead" }, el("span", { className: "box-name f-grow" }, wording("page-lorebooks")), add), list, none)),
    el("p", { className: "lore-note hint" }, wording("persona-form-used-in-every-chat")),
  );
  const ids = (books: PersonaLorebook[]) => books.map((book) => book.id);
  return { node, held: () => (ids(held).join() === ids(given).join() ? undefined : ids(held)) };
}

/**
 * The form, with the persona to change in it or empty. `save` answers whether
 * it was done; after that, and on "Cancel", `close` is called. One such form
 * is on a screen at a time. `take` is what a picked file is given to.
 * `library` is the library's lorebooks, which "+" offers once they are read;
 * without it (the chat's side panel) the form has no box of lorebooks.
 */
export function personaForm(
  save: PersonaSave,
  close: () => void,
  library: Promise<Lorebook[]> | null,
  from?: Persona,
): { node: HTMLFormElement; name: HTMLInputElement; take(file: File): void } {
  const name = el("input", { id: "persona-name", className: "field", required: true, maxLength: 64, value: from?.name ?? "" });
  const description = el("textarea", { id: "persona-description", className: "field", rows: 3, value: from?.description ?? "", placeholder: wording("persona-form-description-hint") });
  /** The picture picked (a file), removed (`null`), or as it was (`undefined`). */
  let picture: File | null | undefined;
  const round = el("span", { className: "initial of-form", ariaHidden: "true" });
  const add = el("button", { type: "button", className: "btn btn-secondary" }, wording("persona-form-add-picture"));
  const remove = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("profile-remove-picture") }, wording("mcp-remove"));
  const change = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("profile-change-picture") }, wording("password-change"));
  /** The address made for a picked file, let go when another is shown. */
  let made = "";
  const show = () => {
    if (made) URL.revokeObjectURL(made);
    made = picture ? URL.createObjectURL(picture) : "";
    const shown = picture === undefined ? from?.picture : made;
    round.replaceChildren(shown ? el("img", { src: shown, alt: "" }) : initialOf(name.value || "?"));
    add.hidden = Boolean(shown);
    remove.hidden = change.hidden = !shown;
  };
  const take = (file: File) => {
    picture = file;
    show();
  };
  const picker = fileField(round, PICTURES.join(","), false, ([file]) => file && take(file));
  add.onclick = change.onclick = () => picker.click();
  remove.onclick = () => {
    picture = null;
    show();
  };
  // The initial follows the name while no picture shows.
  name.addEventListener("input", () => !add.hidden && show());
  show();
  const lorebooks = library ? lorebooksBox(from?.lorebooks ?? [], library) : null;
  const node = el(
    "form",
    { className: "persona-form flex f-col g-14" },
    el("div", { className: "persona-picture flex ai-c g-12" }, round, add, remove, change, picker),
    el("div", { className: "fld" }, el("label", { className: "label", htmlFor: name.id }, wording("common-name")), name),
    el("div", { className: "fld" }, el("label", { className: "label", htmlFor: description.id }, wording("persona-form-description")), description),
    lorebooks?.node,
    el(
      "div",
      { className: "actions flex g-8" },
      el("button", { type: "submit", className: "primary btn btn-primary" }, wording("common-save")),
      el("button", { type: "button", className: "btn btn-secondary", onclick: close }, wording("common-cancel")),
    ),
  );
  // Escape is "Cancel", and the form's alone. Not the one that ends a word an input method is putting together.
  node.onkeydown = (event) => {
    if (event.key !== "Escape" || event.isComposing) return;
    event.preventDefault();
    close();
  };
  node.onsubmit = async (event) => {
    event.preventDefault();
    if (await save(name.value, description.value, picture, lorebooks?.held())) close();
  };
  return { node, name, take };
}
