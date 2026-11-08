// The row "I need…" over the Characters page's view By need: the needs any card has as pills to pick, in the
// server's order (on most cards first) and worded as the interview words them, or while no card has one a grey line. What a pick does to the list is the server's (`need` on the list's query), so no level
// reaches the page. Trap: the list is read anew at every press and every card read, so pills that still stand are
// kept, not drawn anew, or the keyboard's place on them would be lost.
import type { NeedsOverview } from "../api/generated/NeedsOverview";
import { el, pill } from "../dom";
import { needWords } from "../language/interview";
import { wording } from "../language/language";

/** The row; `show` draws what the server last said. */
export interface NeedRow {
  node: HTMLElement;
  show(overview: NeedsOverview): void;
}

/** The grey line in place of the pills while no card has a need. */
const line = ({ read, of }: NeedsOverview): string => (read < of ? wording("library-need-reading", { read, of }) : wording("library-need-none"));

/**
 * Makes the row. A press changes `picks` in place and calls `changed`, which reads the list. A pick no card has any
 * more leaves `picks` when it is shown.
 */
export function needRow(picks: string[], changed: () => void): NeedRow {
  const place = el("div", { className: "pillset minw0" });
  // Under the pills how to pick, and Clear while one is picked.
  const clear = el("button", { type: "button", className: "btn btn-quiet btn-sm", hidden: true }, wording("library-need-clear"));
  const hint = el("div", { className: "flex ai-c g-8 meta" }, el("span", {}, wording("library-need-hint")), clear);
  const node = el(
    "div",
    { className: "need-row flex ai-s g-12" },
    el("span", { className: "need-line semi nowrap f-none" }, wording("library-i-need")),
    el("div", { className: "flex f-col g-8 minw0 f-grow" }, place, hint),
  );
  /** The pills that stand, by need, and the needs they were drawn for. */
  let pills = new Map<string, HTMLButtonElement>();
  let drawn = "";

  const pressed = (need: string, one: HTMLButtonElement) => {
    const at = picks.indexOf(need);
    if (at < 0) picks.push(need);
    else picks.splice(at, 1);
    one.ariaPressed = String(at < 0);
    clear.hidden = !picks.length;
    changed();
  };
  clear.onclick = () => {
    picks.splice(0);
    for (const one of pills.values()) one.ariaPressed = "false";
    clear.hidden = true;
    pills.values().next().value?.focus();
    changed();
  };

  return {
    node,
    show(overview) {
      const having = overview.needs;
      picks.splice(0, picks.length, ...picks.filter((need) => having.includes(need)));
      const now = JSON.stringify(overview.needs);
      if (now !== drawn || !overview.needs.length) {
        drawn = now;
        const made = overview.needs.map((need): [string, HTMLButtonElement] => {
          const one = pills.get(need) ?? pill(needWords(need), false, () => pressed(need, one));
          return [need, one];
        });
        pills = new Map(made);
        const focused = document.activeElement;
        place.replaceChildren(...(made.length ? made.map(([, one]) => one) : [el("span", { className: "need-line meta" }, line(overview))]));
        // Taken out and put back, a pill has lost the focus.
        if (focused instanceof HTMLElement && place.contains(focused)) focused.focus();
      }
      for (const [need, one] of pills) one.ariaPressed = String(picks.includes(need));
      clear.hidden = !picks.length;
      hint.hidden = !pills.size;
    },
  };
}
