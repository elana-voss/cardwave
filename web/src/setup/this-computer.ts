// First run's line "This computer" under "Use a server on this computer" (this computer's account alone): the
// GGUF files of a folder as chat models, run by Cardwave (Settings › Providers has the same box). With a folder
// set, "Use this" goes on with its address and no key; without one, "Choose folder" opens dialogs.ts's dialog
// "Folder", which stores it at once, as Settings › Providers does, and the line then has "Use this".
import { wording } from "../language/language";
import { account } from "../account";
import { getProviderList, setThisComputer } from "../api/client";
import type { EntryView } from "../api/generated/EntryView";
import { el, item } from "../dom";
import { folderDialog } from "../dialogs";

/** The line, for this computer's account; `go` goes on with the address. None for another account. */
export async function thisComputerLine(home: () => HTMLElement, go: (base_url: string) => void): Promise<HTMLElement | null> {
  if (!(await account()).local) return null;
  const own = (await getProviderList()).providers.find((provider) => provider.folder !== null);
  const draw = (entry: EntryView | undefined) => {
    const button = entry
      ? el("button", { type: "button", className: "btn btn-secondary on-box", onclick: () => go(entry.base_url) }, wording("setup-use-this"))
      : el("button", { type: "button", className: "btn btn-secondary on-box", onclick: choose }, wording("setup-choose-folder"));
    return item(wording("setup-this-computer"), entry?.folder ?? wording("setup-this-computer-about"), button);
  };
  let shown = draw(own);
  function choose(): void {
    folderDialog(home(), wording("label-settings-folder"), "", wording("setup-models-example"), wording("setup-models-says"), async (typed) => {
      const view = await setThisComputer(typed);
      const line = draw(view.providers.find((provider) => provider.folder !== null));
      shown.replaceWith(line);
      shown = line;
      line.querySelector("button")?.focus();
    });
  }
  return shown;
}
