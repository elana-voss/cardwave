// First run's third step, "Cards" (milestone 90; no board draws it: docs/design.md, First run), this computer's
// account's alone, as the folder is this computer's: the line "Cards folder" (library/card-folder.ts) and under
// the box what comes of it. As the step shows (`offer`), the folder is the server's offer: the folder of cards
// chosen, else the user's Documents folder. The folder taken is only held in the browser (`FOLDER`, so a start
// during the downloads keeps it): it is stored, and its cards are imported with the import panel, when setup
// ends (`openApp` in models-step.ts, which `forget`s it), so the downloads of step 4 come first and the watch
// takes nothing before. With a folder, "Import from this folder" takes it and "Skip" goes on without; without
// one, "Skip" alone; "Back" is quiet, set apart from them. "Change" opens the picker in the folder shown.
import { wording } from "../language/language";
import { getOfferedCardFolder } from "../api/client";
import { el } from "../dom";
import { chooseFolder, folderLine } from "../library/card-folder";
import { remember, remembered } from "../storage";

/** Where the browser holds the folder taken until setup ends. */
const FOLDER = "setup-cards-folder";

export function cardsStep(home: () => HTMLElement, attempt: (action: () => Promise<void>) => Promise<boolean>) {
  let folder = remembered(FOLDER) || null;
  /** The folder taken at "Continue", kept beside the browser's copy. */
  let taken = folder;
  const line = folderLine(
    () =>
      void attempt(() =>
        chooseFolder(home(), folder ?? "", async (chosen) => {
          folder = chosen.trim() || null;
          show();
        }),
      ),
  );
  const go = el("button", { type: "button", className: "btn btn-primary btn-lg" }, wording("setup-skip"));
  const skip = el("button", { type: "button", className: "btn btn-secondary", hidden: true }, wording("setup-skip"));
  const backButton = el("button", { type: "button", className: "btn btn-quiet" }, wording("setup-back"));
  const node = el(
    "div",
    { className: "setup-step flex f-col g-28", hidden: true },
    el("div", { className: "group" }, line.node),
    el("p", { className: "hint" }, wording("setup-cards-about")),
    el("div", { className: "setup-actions flex ai-c g-10 wrap" }, go, skip, backButton),
  );
  function show(): void {
    line.show(folder);
    go.textContent = folder ? wording("setup-import-folder") : wording("setup-skip");
    skip.hidden = !folder;
  }
  show();
  /** Shows the folder the server offers, where none is held yet; a failure to ask leaves the line without. */
  const offer = async () => {
    if (folder) return;
    folder = await getOfferedCardFolder().catch(() => null);
    show();
  };
  /** Holds the folder shown where `use` ("Continue"), none where not ("Skip"), until setup ends. */
  const take = (use: boolean) => {
    if (!use) folder = null;
    taken = folder;
    remember(FOLDER, folder ?? "");
  };
  /** The folder taken, if any. */
  const chosen = () => taken;
  /** Lets the folder go, once setup has used it. */
  const forget = () => {
    folder = taken = null;
    remember(FOLDER, "");
  };
  return { node, go, skip, backButton, offer, take, chosen, forget, focus: () => line.button.focus() };
}
