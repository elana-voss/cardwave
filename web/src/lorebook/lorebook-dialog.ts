// The dialogs of a lorebook's name and description: `aboutDialog`, which the editor (views/lorebook.ts) opens
// as "Lorebook settings" with the lorebook's own numbers and, of one of the library, "Use in every chat", and `newLorebook`, the window "New lorebook" (without
// the numbers), which the list of lorebooks and Create open.
import { createLorebook } from "../api/client";
import { atMost, el, switchBox } from "../dom";
import { formDialog } from "../dialogs";
import { NEW } from "./entry";
import { wording } from "../language/language";

/** How many signs a lorebook's and an entry's name may have. */
export const MAX_NAME = 64;

/** A lorebook's own numbers, as "Lorebook settings" changes them, 0 for none; and of one of the library whether every chat has it. */
type Numbers = { scan_depth: number; token_budget: number; everywhere?: boolean };

/**
 * Opens a dialog of a lorebook's name and description, `title`, over `home`, which begins with `name` and
 * `description`, and with `numbers` the fields of its scan depth and token budget; "Save" hands what is typed
 * to `save`, which closes the dialog once it has saved.
 */
export function aboutDialog(
  home: HTMLElement,
  title: string,
  name: string,
  description: string,
  save: (name: string, description: string, box: HTMLDialogElement, numbers?: Numbers) => Promise<void>,
  numbers?: { scan_depth: number | null; token_budget: number | null; everywhere?: boolean },
): void {
  const called = el("input", { id: "lorebook-name", className: "field", value: name, required: true });
  atMost(called, MAX_NAME);
  const described = el("textarea", { id: "lorebook-description", className: "field", rows: 5, value: description });
  const number = (id: string, value: number | null) => el("input", { id, type: "number", min: "0", step: "1", className: "field number", value: value ? String(value) : "" });
  const depth = number("lorebook-scan-depth", numbers?.scan_depth ?? null);
  const budget = number("lorebook-token-budget", numbers?.token_budget ?? null);
  const everywhere = switchBox({ id: "lorebook-everywhere", checked: numbers?.everywhere ?? false });
  const fields = [
    el("div", { className: "fld" }, el("label", { htmlFor: called.id }, wording("common-name")), called),
    el("div", { className: "fld" }, el("label", { htmlFor: described.id }, wording("persona-form-description")), described),
    ...(numbers
      ? [
          el("div", { className: "fld" }, el("label", { htmlFor: depth.id }, wording("lorebook-dialog-messages-searched")), depth, el("p", { className: "meta" }, wording("lorebook-dialog-how-many-of-the"))),
          el("div", { className: "fld" }, el("label", { htmlFor: budget.id }, wording("lorebook-dialog-token-limit")), budget, el("p", { className: "meta" }, wording("lorebook-dialog-the-most-tokens-its"))),
        ]
      : []),
    ...(numbers?.everywhere !== undefined
      ? [
          el(
            "div",
            { className: "fld" },
            el("label", { className: "switch-line flex ai-c g-10" }, el("span", { className: "f-grow" }, wording("lorebook-dialog-use-in-every-chat")), everywhere),
            el("p", { className: "meta" }, wording("lorebook-dialog-every-chat-with-a")),
          ),
        ]
      : []),
  ];
  const box = formDialog(home, title, fields, () =>
    save(called.value, described.value, box, numbers && {
        scan_depth: Number(depth.value) || 0,
        token_budget: Number(budget.value) || 0,
        ...(numbers.everywhere !== undefined && { everywhere: everywhere.checked }),
      },
    ),
  );
}

/** Opens the window "New lorebook" over `home`: the lorebook named there is made without entries, and its editor shows a new entry. */
export function newLorebook(home: HTMLElement): void {
  aboutDialog(home, wording("create-new-lorebook"), "", "", async (name, description, box) => {
    const made = await createLorebook({ name, description });
    box.close();
    location.hash = `#/library/lorebooks/${made.id}/${NEW}`;
  });
}
