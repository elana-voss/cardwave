// The folder of cards (milestone 90), what first run's step "Cards" (setup/cards-step.ts) and Settings › Data
// (settings/card-folder.ts) share: its line, "Cards folder" with the folder or what it is for and "Choose folder"
// or "Change"; the folder chosen (`chooseFolder`): in the desktop app by the system's folder picker, in a browser
// typed into dialogs.ts's dialog "Cards folder", its button "Use this folder"; the folder shown cut in the middle, whole as its tooltip; and the folder used (`useCardFolder`): stored in the settings, then
// its cards imported, which the import panel follows (importing.ts). The folder is this computer's, so all of it
// is this computer's account's alone.
import { ApiError, changeSettings, importCardFolder } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import { inDesktop, pickFolder } from "../desktop";
import { folderDialog } from "../dialogs";
import { el, item } from "../dom";
import { folderShort } from "../format";
import { LABELS } from "../setting-labels";
import { followFolderImport } from "./importing";
import { wording } from "../language/language";


/** The line "Cards folder": `show` has it say the folder, or without one what it is for, and its button what it does. */
export function folderLine(choose: () => void) {
  const says = el("span", { className: "meta" }, wording("card-folder-none"));
  const button = el("button", { type: "button", className: "btn btn-secondary on-box", onclick: choose }, wording("setup-choose-folder"));
  const node = item(LABELS.settings.cardsFolder, says, button);
  const show = (folder: string | null) => {
    says.textContent = folder ? folderShort(folder) : wording("card-folder-none");
    says.title = folder ?? "";
    button.textContent = folder ? wording("password-change") : wording("setup-choose-folder");
    button.ariaLabel = folder ? wording("card-folder-change-the-cards-folder") : null;
  };
  return { node, show, button };
}

/**
 * Has the user choose a folder, starting at `start`, and hands it to `take`:
 * in the desktop app the system's picker, where a failure of `take` rejects
 * for the caller to say; in a browser the dialog "Folder", which says it.
 */
export async function chooseFolder(home: HTMLElement, start: string, take: (folder: string) => Promise<void>): Promise<void> {
  if (!inDesktop()) return folderDialog(home, LABELS.settings.cardsFolder, start, wording("card-folder-c-users-you-cards"), wording("card-folder-its-card-files-and"), take, wording("card-folder-use"));
  const chosen = await pickFolder(start);
  if (chosen) await take(chosen);
}

/** Stores `folder` as the folder of cards and imports its cards, which the import panel shows; one going on is followed. Answers the settings stored. */
export async function useCardFolder(folder: string): Promise<Settings> {
  const settings = await changeSettings({ card_folder: { folder } });
  try {
    await importCardFolder(folder);
  } catch (error) {
    // Another import of a folder goes on (409): the panel follows that one, and the watch takes this folder's cards after it.
    if (!(error instanceof ApiError && error.status === 409)) throw error;
  }
  void followFolderImport();
  return settings;
}
