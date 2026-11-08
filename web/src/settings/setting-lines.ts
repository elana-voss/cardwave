// Parts of a settings line shared by Settings and Settings › Advanced: `settingSwitch`, the switch of a setting
// of the server's that is on or off, and `lineFiller`, which fills a line of a group by itself.
import { changeSettings } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import { failure, reason, switchBox, type oneAtATime } from "../dom";

/**
 * The switch of a setting that is on or off, which cannot be pressed until `show` has shown what the server holds,
 * nor while its change is on its way, so it never shows what the server does not hold.
 */
export function settingSwitch(attempt: ReturnType<typeof oneAtATime>, label: string, key: "describe_imported" | "export_history" | "web_pictures" | "check_updates" | "watch" | "recycle") {
  const toggle = switchBox({ ariaLabel: label, disabled: true });
  // The folder of cards' two are held within its settings.
  const held = (settings: Settings) => (key === "watch" || key === "recycle" ? settings.card_folder[key] : settings[key]);
  const change = (on: boolean) => (key === "watch" || key === "recycle" ? { card_folder: { [key]: on } } : { [key]: on });
  toggle.onchange = () =>
    attempt(async () => {
      toggle.disabled = true;
      try {
        toggle.checked = held(await changeSettings(change(toggle.checked)));
      } catch (error) {
        toggle.checked = !toggle.checked;
        throw error;
      } finally {
        toggle.disabled = false;
      }
    });
  const show = (settings: Settings) => {
    toggle.checked = held(settings);
    toggle.disabled = false;
  };
  return { toggle, show };
}

/**
 * Fills a line of a group by itself: one that cannot be filled does not hold up the others, and says why in
 * `notice`, beside what the others say there. Answers how the line's asking is let go: what it comes to after
 * that is not shown, and why it failed is said no longer, while what the other lines said stays.
 */
export function lineFiller(notice: HTMLElement) {
  return <T>(read: () => Promise<T>, show: (answer: T) => void): (() => void) => {
    let asking = true;
    let why: HTMLElement | null = null;
    void read()
      .then((answer) => {
        if (asking) show(answer);
      })
      .catch((error) => {
        if (asking) notice.append((why = failure(reason(error))));
      });
    return () => {
      asking = false;
      why?.remove();
    };
  };
}
