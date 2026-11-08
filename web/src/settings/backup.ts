// A backup of all Cardwave holds, with its key (crates/cw-store/src/backup.rs).
//
// `backupLine` is the lines "Backup" and "Restore" of Settings › Data: what a backup holds and which password
// locks it (`show`), with "Back up"; and "Restore". A backup always has a password (the owner): where none is on,
// "Back up" asks for one first (`backupDialog`). It has the browser save the file as the server sends it, never held
// in the page (a backup holds everything), and says where to, where that is known, or why the server made none.
// "Restore" opens `restoreDialog`: the file picked, and the password the
// backup was made with, asked once the server says that it needs one (401). What the backup holds then takes the
// place of all the app holds, and the server tells every page, which starts anew (`restored` in main.ts).
import { wording } from "../language/language";
import { ApiError, restoreBackup, saveBackup } from "../api/client";
import { announce, el, fileField } from "../dom";
import { formDialog } from "../dialogs";
import { field } from "./password";
import { LABELS } from "../setting-labels";

/** Has the browser save a backup, sealed by `password` where none is on, and says where to. */
function keep(password?: string): void {
  saveBackup(password, (reason) => announce(reason));
  const folder = window.cardwaveDesktop?.downloads;
  announce(folder ? wording("backup-saving-to", { folder }) : wording("backup-saving"));
}

/** Opens the dialog that asks for the backup's password where none is on, in `home`, of the Password dialog's parts. */
export function backupDialog(home: HTMLElement): HTMLDialogElement {
  const password = field("backup-new", wording("backup-password"), "new-password");
  const repeat = field("backup-repeat", wording("backup-repeat"), "new-password");
  const fields = [
    el("p", { className: "dialog-says hint c-ink" }, wording("backup-encrypted")),
    password.node,
    repeat.node,
    el("p", { className: "banner warning" }, wording("backup-forgotten")),
  ];
  const box = formDialog(
    home,
    wording("backup-with-password"),
    fields,
    async () => {
      if (password.input.value !== repeat.input.value) throw new Error(wording("backup-differ"));
      box.close();
      keep(password.input.value);
    },
    wording("backup-back-up"),
  );
  password.input.focus();
  return box;
}

/** Opens the dialog that restores a backup, in `home`. */
export function restoreDialog(home: HTMLElement): HTMLDialogElement {
  let file: File | null = null;
  const chosen = el("span", { className: "meta chosen-file minw0 ellipsis" }, wording("backup-no-file"));
  const choose = el("button", { type: "button", className: "btn btn-secondary" }, wording("backup-choose-file"));
  const picker = fileField(choose, ".cwbackup", false, ([picked]) => {
    file = picked ?? null;
    chosen.textContent = picked?.name ?? wording("backup-no-file");
  });
  choose.onclick = () => picker.click();
  const password = el("input", { id: "backup-password", className: "field", type: "password", autocomplete: "off" });
  const asking = el("div", { className: "fld", hidden: true }, el("label", { htmlFor: password.id }, wording("backup-its-password")), password);
  const fields = [
    el("p", { className: "dialog-says hint c-ink" }, wording("backup-restoring")),
    el("div", { className: "fld" }, el("span", { className: "field-name label" }, wording("backup-file")), el("div", { className: "find flex ai-c g-8" }, choose, chosen), picker),
    asking,
  ];
  const box = formDialog(
    home,
    wording("backup-restore-title"),
    fields,
    async () => {
      if (!file) throw new Error(wording("backup-choose-first"));
      try {
        await restoreBackup(file, asking.hidden ? undefined : password.value);
      } catch (error) {
        // A backup made with a password is asked for it.
        if (error instanceof ApiError && error.status === 401) {
          asking.hidden = false;
          password.focus();
        }
        throw error;
      }
      // The server tells every page, this one too, which starts anew with what the backup held.
      box.close();
    },
    wording("backup-restore"),
  );
  return box;
}

/** The lines "Backup" and "Restore": `home` is the screen the dialog stands in. */
export function backupLine(home: () => HTMLElement): { nodes: HTMLElement[]; show(password: boolean): void } {
  const says = el("span", { className: "meta" });
  // Until `show` has told whether a password is on, Back up would not know whether to ask for one.
  let on = false;
  const backUp = () => (on ? keep() : backupDialog(home()));
  const nodes = [
    el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, LABELS.settings.backup), says), el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("backup-save"), disabled: true, onclick: backUp }, wording("backup-back-up"))),
    el(
      "div",
      { className: "item" },
      el("div", { className: "item-text" }, el("span", { className: "item-label" }, LABELS.settings.restore), el("span", { className: "meta" }, wording("backup-from-file"))),
      el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("backup-restore-title"), onclick: () => restoreDialog(home()) }, wording("backup-restore")),
    ),
  ];
  const show = (password: boolean) => {
    on = password;
    nodes[0].querySelector("button")!.disabled = false;
    says.textContent = password ? wording("backup-about-own") : wording("backup-about-chosen");
  };
  return { nodes, show };
}
