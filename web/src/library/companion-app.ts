// The companion as the app's window has it (the companion window itself is companion/main.ts): the settings' line
// "Companion" in Appearance, the line "Make companion" of a card's menu, the companion started with the app, and
// `pickCompanion`, the window "Companion" that the companion's "Change character" opens here (at `#/companion`).
// All four are the desktop app's alone (`inDesktop`), as only it has the companion's window, which its program
// opens and closes (desktop.ts).
//
// The switch says whether the companion is out, and starts with the app: on, it opens the window; off, it closes it.
// "Make companion" makes the card's first character the companion and opens the window, or has an open one show it.
// `figureLine`, "Companion figure" (Settings' Appearance and first run's step 2, Claude), picks the figure shown
// where the card has none, stored at once; a refused change marks the figure stored before. `sizeLine`, "Companion
// size" under it in Settings (Claude), sets the figure's height as a share of the screen's, stored as the slider
// moves, one change at a time, the newest last, so the companion window resizes it live.
import { wording } from "../language/language";
import { changeCompanion, getCard, getSettings } from "../api/client";
import type { CardSummary } from "../api/generated/CardSummary";
import type { Companion } from "../api/generated/Companion";
import { companionDialog } from "./add-character";
import { announce, el, failure, item, noticeBox, reason, savedChoice, switchBox } from "../dom";
import type { BaseFigure } from "../api/generated/BaseFigure";
import { type MenuItem } from "../dialogs";
import { desktop, inDesktop } from "../desktop";
import { cardTitle } from "../card-title";

/** Opens the companion's window as the app starts, where the settings say so; once, however often the page starts. */
export function startCompanion(): void {
  if (!inDesktop()) return;
  void getSettings()
    .then(({ companion }) => companion.starts && companion.card_id !== null && desktop("companion_start"))
    .catch(() => {});
}

/** Makes the card the companion, `name` in the notice, and opens the window, or has an open one show it. */
async function makeCompanion(cardId: number, name: string): Promise<void> {
  await changeCompanion({ card_id: cardId, starts: true, hidden_until: null });
  await desktop("companion_open");
  announce(wording("companion-made", { name }));
}

/** The line "Make companion" of a card's menu, in the desktop app. */
export function companionItem(card: CardSummary, run: (action: () => Promise<void>) => unknown): MenuItem[] {
  if (!inDesktop()) return [];
  return [{ label: wording("companion-make"), shape: "person", action: () => void run(() => makeCompanion(card.id, cardTitle(card.title))) }];
}

/** The window "Companion" over `home`: the card picked becomes the companion; why it did not stands in the notice. */
export function pickCompanion(home: HTMLElement): void {
  companionDialog(home, (pick) => void makeCompanion(pick.cardId, pick.name).catch((error) => announce(reason(error))));
}

/** The settings' line "Companion", in the desktop app, and `read`, which reads it anew; nothing in a browser. */
export function companionLine(): { node: HTMLElement; read(): void } | null {
  if (!inDesktop()) return null;
  const toggle = switchBox({ ariaLabel: wording("companion"), disabled: true });
  const says = el("span", { className: "meta" }, "");
  const line = item(wording("companion"), says, toggle);
  let companion: Companion | null = null;
  const draw = (name: string | null) => {
    toggle.checked = companion?.starts ?? false;
    toggle.disabled = companion?.card_id == null;
    says.textContent = name === null ? wording("companion-none") : wording("companion-named", { name });
  };
  const read = async () => {
    companion = (await getSettings()).companion;
    const card = companion.card_id === null ? null : await getCard(companion.card_id).catch(() => null);
    draw(card?.characters[0]?.name ?? (card ? cardTitle(card.card.title) : null));
  };
  toggle.onchange = () => {
    if (!companion) return;
    const on = toggle.checked;
    toggle.disabled = true;
    void changeCompanion(on ? { starts: on, hidden_until: null } : { starts: on })
      .then(() => desktop(on ? "companion_open" : "companion_quit"))
      .then(read)
      .catch((error) => {
        says.replaceChildren(failure(reason(error)));
        void read().catch(() => {});
      });
  };
  const shown = () => void read().catch((error) => says.replaceChildren(failure(reason(error))));
  shown();
  return { node: line, read: shown };
}

/** The line "Companion figure", in the desktop app: the figure shown where the companion's card has none, and
 * `notice`, which says why it was not read or not stored, and `read`, which reads it anew; nothing in a browser. */
export function figureLine(): { node: HTMLElement; notice: HTMLElement; read(): void } | null {
  if (!inDesktop()) return null;
  const notice = noticeBox();
  const options: [BaseFigure, string][] = [
    ["woman", wording("companion-figure-woman")],
    ["man", wording("companion-figure-man")],
    ["robot", wording("companion-figure-robot")],
  ];
  const label = wording("companion-figure");
  const choice = savedChoice(label, options, notice, async () => (await getSettings()).companion.figure, async (figure) => (await changeCompanion({ figure })).companion.figure);
  return { node: item(label, wording("companion-figure-about"), choice.node), notice, read: choice.read };
}

/** The line "Companion size", in the desktop app: a slider of `COMPANION_SIZES` percent of the screen's height,
 * stored as it moves; `notice` says why it was not read or not stored, and `read` reads it anew. */
export function sizeLine(notice: HTMLElement): { node: HTMLElement; read(): void } | null {
  if (!inDesktop()) return null;
  const said = (size: number) => wording("companion-size-value", { size });
  const shown = el("span", { className: "meta lv-val" }, "");
  const slider = el("input", { type: "range", min: "10", max: "50", step: "1", disabled: true, ariaLabel: wording("companion-size") });
  // While the slider is in hand, what the settings say is behind it, and does not move it.
  const show = (size: number, always = false) => {
    if (!always && !slider.disabled && document.activeElement === slider) return;
    slider.value = String(size);
    shown.textContent = said(size);
    slider.disabled = false;
  };
  // The size being stored, and the newest asked for while it was: stored after it; `moves`, the slider's moves so far.
  let storing = false;
  let moves = 0;
  let next: number | null = null;
  const store = async (size: number): Promise<void> => {
    storing = true;
    notice.replaceChildren();
    try {
      await changeCompanion({ size });
    } catch (error) {
      notice.replaceChildren(failure(reason(error)));
      next = null;
      // What is stored is shown again, unless the slider has moved on before the settings answer.
      const at = moves;
      read(true, () => moves === at);
    }
    storing = false;
    if (next !== null) void store(next);
    next = null;
  };
  slider.oninput = () => {
    const size = Number(slider.value);
    moves += 1;
    shown.textContent = said(size);
    if (storing) next = size;
    else void store(size);
  };
  const read = (always = false, still = () => true) =>
    void getSettings().then(({ companion }) => still() && show(companion.size, always), (error: unknown) => notice.replaceChildren(failure(reason(error))));
  read();
  return { node: item(wording("companion-size"), wording("companion-size-about"), el("div", { className: "lv" }, slider, shown)), read: () => read() };
}
