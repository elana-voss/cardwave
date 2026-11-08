// The app's updates, in the desktop app alone (desktop/src/update.rs, Tauri's updater, which installs only an
// update signed with the project's key). Settings' last box has "Check for updates", whose check opens a window
// with what it found, as the Flutter app's did: a newer version with both versions, its notes (the release's on
// GitHub, English in every language) and "Update and restart"; else up to date or why the check failed (GitHub
// not reached, or anything else), with "OK", the button saying "Checking…" meanwhile; under it the switch "Check
// automatically" (the setting `check_updates`, on at first). `watchUpdates`, from main.ts, checks at start and once a day while that
// is on, quietly: only a newer version is said, in the notice at the window's foot with "Update and restart",
// never in a window. Installing says so in the notice; the app then ends and its installer starts it anew.
import { wording } from "../language/language";
import { getSettings } from "../api/client";
import { announce, el, item, noticeBox, oneAtATime, reason, toast } from "../dom";
import { dialog } from "../dialogs";
import { desktop, inDesktop } from "../desktop";
import { settingSwitch } from "./setting-lines";

/** What the desktop app's check found: this version, and the newer one with its notes where there is one. */
interface Checked {
  current: string;
  latest: string | null;
  notes: string | null;
}

/** How often the app looks again while it runs. */
export const DAY = 24 * 60 * 60 * 1000;

const checkUpdate = () => desktop("update_check") as Promise<Checked>;

/** Downloads and installs `version`, which the last check found, saying so in the notice until the app ends. */
async function install(version: string): Promise<void> {
  toast().replaceChildren(el("span", null, wording("update-installing", { version })));
  await desktop("update_install");
}

/** Installs as `install`, a failure said in the notice. */
const installTold = (version: string) => void install(version).catch((error: unknown) => announce(reason(error)));

/** What a check's window says: its title, its paragraphs, the release notes, and the version it offers to install. */
interface Said {
  title: string;
  lines: string[];
  notes: string | null;
  offers: string | null;
}

/** The line's name, and the title of every window but a new version's. */
const title = () => wording("update-title");

/**
 * The window of a failed check, told by what the updater's error allows: GitHub not reached (reqwest's "error sending
 * request", which a lost connection, a name not found and a timeout all are) or anything else GitHub answered.
 */
function failed(error: unknown): Said {
  const text = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const unreached = /sending request|connect|timed out|dns/i.test(text);
  return { title: title(), lines: [unreached ? wording("update-connection-error") : wording("update-check-failed")], notes: null, offers: null };
}

/** The window an answer of the check opens. */
function said(found: Checked): Said {
  if (!found.latest) return { title: title(), lines: [wording("update-up-to-date", { version: found.current })], notes: null, offers: null };
  return {
    title: wording("update-available", { version: found.latest }),
    lines: [wording("update-you-have", { version: found.current })],
    notes: found.notes,
    offers: found.latest,
  };
}

/** Opens the window `what` says in `home`. */
function showUpdate(home: HTMLElement, what: Said): HTMLDialogElement {
  const body = el("div", { className: "update-body dlg-body" }, ...what.lines.map((line, n) => el("p", { className: n ? "meta m0" : "m0" }, line)));
  if (what.notes) body.append(el("p", { className: "m0" }, el("b", null, wording("update-whats-new"))), el("p", { className: "update-notes m0" }, what.notes));
  const close = el("button", { type: "button", className: what.offers ? "btn btn-secondary" : "primary btn btn-primary" }, what.offers ? wording("update-close") : wording("update-ok"));
  const foot = el("div", { className: "dfoot dialog-foot" }, close);
  const box = dialog(home, what.title, body, foot);
  close.onclick = () => box.close();
  const version = what.offers;
  if (version) {
    const update = el("button", { type: "button", className: "primary btn btn-primary" }, wording("update-install"));
    update.onclick = () => {
      box.close();
      installTold(version);
    };
    foot.prepend(update);
  }
  return box;
}

/**
 * Settings' lines "Check for updates", whose button checks and opens the answer's window in `home`, and "Check
 * automatically", with the notice its switch says a failure in; in the desktop app alone.
 */
export function updateLines(home: () => HTMLElement): { notice: HTMLElement; lines: HTMLElement[] } | null {
  if (!inDesktop()) return null;
  const button = el("button", { type: "button", className: "btn btn-secondary on-box" }, wording("update-check"));
  button.onclick = async () => {
    button.disabled = true;
    button.textContent = wording("update-checking");
    const what = await checkUpdate().then(said, failed);
    button.disabled = false;
    button.textContent = wording("update-check");
    showUpdate(home(), what);
  };
  const notice = noticeBox();
  const auto = settingSwitch(oneAtATime(notice), wording("update-auto"), "check_updates");
  void getSettings().then(auto.show, (error: unknown) => notice.replaceChildren(reason(error)));
  return { notice, lines: [item(title(), wording("update-about"), button), item(wording("update-auto"), wording("update-auto-about"), auto.toggle)] };
}

/** In the desktop app, looks for a newer version now and once a day while the settings say so; only one found is said. */
export function watchUpdates(): void {
  if (!inDesktop()) return;
  const look = async () => {
    if (!(await getSettings().then((settings) => settings.check_updates, () => false))) return;
    const found = await checkUpdate().catch(() => null);
    const version = found?.latest;
    if (version) announce(wording("update-available", { version }), async () => installTold(version), true, wording("update-install"));
  };
  void look();
  setInterval(() => void look(), DAY);
}
