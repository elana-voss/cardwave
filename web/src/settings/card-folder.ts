// Settings › Data's folder of cards (milestone 90): "Cards folder" (library/card-folder.ts), which a folder picked
// or changed stores and whose cards it then imports with the import panel; under it, once a folder is set, the
// switches "Import new cards automatically" (the server's watch, on at first) and "Move imported files to the
// Recycle Bin" (off at first), the last only where the server has a Recycle Bin (`Status.recycle_bin`, Windows).
// The folder is this computer's, so another account has none of the lines (the server answers 403).
import { wording } from "../language/language";
import { getStatus } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import { account } from "../account";
import { el, item, type oneAtATime } from "../dom";
import { chooseFolder, folderLine, useCardFolder } from "../library/card-folder";
import { settingSwitch } from "./setting-lines";

/** The lines, hidden until it is known that the account is this computer's; `show` shows what the settings hold. */
export function cardFolderLines(home: () => HTMLElement, attempt: ReturnType<typeof oneAtATime>) {
  let folder: string | null = null;
  let bin = false;
  const line = folderLine(() => void attempt(() => chooseFolder(home(), folder ?? "", async (chosen) => show(await useCardFolder(chosen)))));
  const watch = settingSwitch(attempt, wording("folder-watch"), "watch");
  const recycle = settingSwitch(attempt, wording("folder-recycle"), "recycle");
  const watched = item(wording("folder-watch"), wording("folder-watch-about"), watch.toggle);
  const binned = item(wording("folder-recycle"), wording("folder-recycle-about"), recycle.toggle);
  const nodes = [line.node, watched, binned];
  let local = false;
  const place = () => {
    line.node.hidden = !local;
    watched.hidden = !local || folder === null;
    binned.hidden = watched.hidden || !bin;
  };
  place();
  void account().then(({ local: here }) => {
    local = here;
    place();
  }, () => {});
  // Without an answer the switch stays hidden: the server refuses it where it cannot move a file.
  void getStatus().then(({ recycle_bin }) => {
    bin = recycle_bin;
    place();
  }, () => {});
  const show = (settings: Settings) => {
    folder = settings.card_folder.folder;
    line.show(folder);
    watch.show(settings);
    recycle.show(settings);
    place();
  };
  return { nodes, show };
}
