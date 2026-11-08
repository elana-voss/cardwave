// A prompt preset's editor: its name, the system prompt that takes the place of the card's, and the author's note
// with the depth it is put at in the chat. "Save" keeps it and leads back to the page "Advanced"; "Cancel" and
// leaving keep nothing.
//
// At `#/settings/advanced/prompts/{id}`, and `…/prompts/new` for one not made yet: the card editor's parts
// (`.page.editing`, `form.editor` with `.edit-column > .edit-group`, `.edit-actions > .edit-buttons`), with the
// path "Settings / Advanced / [name]". An editor of a preset that is gone says why in its notice.
import { wording } from "../language/language";
import { changePromptPreset, createPromptPreset, listPromptPresets } from "../api/client";
import type { EditPromptPreset } from "../api/generated/EditPromptPreset";
import { announce, atMost, el, noticeBox, oneAtATime, titled, type View } from "../dom";
import { count, field, line } from "../edit-form";
import { refusedName } from "../settings/prompt-presets";

/** How many signs a preset's name may have, as the server counts them (`NAME_LIMIT` in crates/cw-provider/src/lib.rs). */
const MAX_NAME = 60;

const ADVANCED = "#/settings/advanced";

export function promptPresetView(id: number | null): View {
  const here = el("b", null, id === null ? wording("prompt-new") : wording("page-prompt-preset"));
  const notice = noticeBox();
  const column = el("div", { className: "page-col edit-column" });
  const cancel = el("button", { type: "button", className: "btn btn-secondary", onclick: () => (location.hash = ADVANCED) }, wording("common-cancel"));
  const buttons = el("div", { className: "flex g-8" }, el("button", { type: "submit", className: "btn btn-primary" }, wording("common-save")), cancel);
  const form = el("form", { className: "editor", hidden: true }, column, el("div", { className: "form-foot" }, buttons));
  const node = el(
    "section",
    { className: "main g-24 rel" },
    el("header", { className: "page-head" }, el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("a", { href: ADVANCED }, wording("page-advanced")), "/", here)),
    notice,
    form,
  );
  const attempt = oneAtATime(notice);

  function show(preset: EditPromptPreset): void {
    const name = line(preset.name, (value) => (preset.name = value), true);
    atMost(name, MAX_NAME);
    const text = (value: string, set: (value: string) => void, rows: number) => {
      const area = el("textarea", { className: "field", value, rows });
      area.oninput = () => set(area.value);
      return area;
    };
    const depth = count(preset.authors_note_depth, (value) => (preset.authors_note_depth = value), { least: 1 });
    column.replaceChildren(
      el(
        "section",
        { className: "edit-fields" },
        el("p", { className: "m0" }, wording("prompt-intro")),
        field(wording("common-name"), name),
        field(wording("promptpage-system"), text(preset.system_prompt, (value) => (preset.system_prompt = value), 10), [], wording("prompt-system-about")),
        field(wording("promptpage-note"), text(preset.authors_note, (value) => (preset.authors_note = value), 4), [], wording("prompt-note-about")),
        field(wording("prompt-depth"), depth, [], wording("prompt-depth-about")),
      ),
    );
    form.hidden = false;
    form.onsubmit = (event) => {
      event.preventDefault();
      void attempt(async () => {
        const refused = refusedName(preset.name);
        if (refused) throw new Error(refused);
        const kept = id === null ? await createPromptPreset(preset) : await changePromptPreset(id, preset);
        announce(wording("prompt-saved", { name: kept.name }), undefined, true);
        location.hash = ADVANCED;
      });
    };
    name.focus();
  }

  if (id === null) show({ name: "", system_prompt: "", authors_note: "", authors_note_depth: 4 });
  else
    void attempt(async () => {
      const found = (await listPromptPresets()).find((preset) => preset.id === id);
      if (!found) throw new Error(wording("prompt-gone"));
      here.textContent = found.name;
      titled(node, found.name);
      const { name, system_prompt, authors_note, authors_note_depth } = found;
      show({ name, system_prompt, authors_note, authors_note_depth });
    });
  return { node: node };
}
