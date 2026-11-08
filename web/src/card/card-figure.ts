// The part "3D figure" of a card page's box (board "Card page · expressions and 3D figure"): what the desktop
// companion shows for the card, a line with its still and name (not its file's format), whose × takes it off the card (with Undo), and
// a line for each of the card's modes that has its own (Claude: "· in [mode]"); "+" opens "Add a 3D figure" (board
// "Add a 3D figure"): the figures the app holds, one chosen and given by "Add", or "From a file…", a VRM, GLB or FBX
// of a rigged human, read here first (figures/load.ts), refused where its skeleton is not one the animations move,
// and drawn once for its still (figures/still.ts), which the server keeps with it. A card with modes has "Used for" over
// the list (Claude): the card, or one of its modes, which then shows its own in place of the card's; above it, the dialog's
// first line says what a figure is for (Claude). The dialog is held-dialog.ts's.
//
// Traps: three.js and three-vrm are loaded only when a file is read, so the card page stays light.
import { figureFromFile, figures, figureStillUrl, setCardFigure } from "../api/client";
import type { Figure } from "../api/generated/Figure";
import { modes, type Card } from "./card-page";
import { announce, el, lineButton, segmented } from "../dom";
import { heldDialog } from "./held-dialog";
import { icon } from "../icons";
import { wording } from "../language/language";

const still = (figure: Figure, className: string) => el("img", { className, src: figureStillUrl(figure.id), alt: "" });


/** The figure the card, or its mode `mode`, has as its own. */
const ownOf = (c: Card, mode: string | null) => (mode === null ? c.figures.figure : (c.figures.modes.find((one) => one.mode === mode)?.figure ?? null));

/** The part, its head and its lines; `redraw` draws the box anew, with the control it names in focus. */
export function figurePart(c: Card, redraw: (focus: string) => void): { tools: HTMLElement[]; rows: HTMLElement[] } {
  const card = c.id!;
  const add = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("card-figure-add-a-3d-figure"), title: wording("card-figure-add-a-3d-figure") }, icon("plus", 16));
  add.onclick = () => void addDialog(c, redraw);
  const put = (figure: number | null, mode: string | null) =>
    c.attempt(async () => {
      c.figures = (await setCardFigure(card, figure, mode)).figures;
      redraw(wording("card-figure-add-a-3d-figure"));
    });
  const takeOff = (figure: Figure, mode: string | null) =>
    c.attempt(async () => {
      const { before, figures } = await setCardFigure(card, null, mode);
      c.figures = figures;
      redraw(wording("card-figure-add-a-3d-figure"));
      announce(mode === null ? wording("card-figure-3d-figure-removed-from") : wording("card-figure-3d-figure-removed-from-2", { mode }), async () => void (await put(before, mode)));
    });
  const row = (figure: Figure, mode: string | null) =>
    el(
      "li",
      { className: "bline row figure-row" },
      el("span", { className: "f-grow flex ai-c g-10" }, still(figure, "fig-small"), el("span", null, figure.name), mode !== null && el("span", { className: "meta" }, wording("card-figure-in", { mode }))),
      lineButton(mode === null ? wording("card-box-remove-from-this-card-2", { name: figure.name }) : wording("card-figure-remove-from", { name: figure.name, mode }), wording("mcp-remove"), "close", () => void takeOff(figure, mode)),
    );
  const own = c.figures.figure;
  const rows = [...(own ? [row(own, null)] : []), ...c.figures.modes.map(({ mode, figure }) => row(figure, mode))];
  return { tools: [add], rows };
}

/** "Add a 3D figure": what a figure is for and, where the card has modes, for which; the figures the app holds; Add, From a file…, Cancel. */
function addDialog(c: Card, redraw: (focus: string) => void): Promise<void> {
  const card = c.id!;
  let mode: string | null = null;
  const cardModes = modes(c);
  const given = (changed: { figures: Card["figures"] }) => {
    c.figures = changed.figures;
    return ownOf(c, mode);
  };
  return heldDialog(c, redraw, {
    title: wording("card-figure-add-a-3d-figure"),
    searched: wording("card-figure-search-figures"),
    empty: wording("card-figure-no-3d-figures-yet"),
    accept: ".vrm,.glb,.fbx",
    many: false,
    head: (rechoose) =>
      el(
        "div",
        { className: "flex f-col g-12" },
        el("p", { className: "meta" }, wording("card-figure-what")),
        cardModes.length
          ? el(
              "div",
              { className: "figure-for flex ai-c g-12" },
              el("span", { className: "meta" }, wording("card-figure-for")),
              segmented<string | null>(wording("card-figure-for"), [[null, wording("card-figure-the-card")], ...cardModes.map((one): [string, string] => [one, one])], null, (now) => {
                mode = now;
                rechoose();
              }),
            )
          : null,
      ),
    picture: (figure) => still(figure, "fig"),
    current: () => ownOf(c, mode)?.id ?? null,
    addedTo: () => (mode === null ? wording("held-dialog-this-card") : mode),
    held: figures,
    give: async (id) => given(await setCardFigure(card, id, mode)),
    fromFiles: async ([file]) => {
      const { kindOf, loadFigure } = await import("../figures/load");
      const { stillOf } = await import("../figures/still");
      const kind = kindOf(file.name);
      if (!kind) throw new Error(wording("card-figure-a-3d-figure-is"));
      const url = URL.createObjectURL(file);
      try {
        return given(await figureFromFile(card, file, await stillOf(await loadFigure(url, kind)), mode));
      } finally {
        URL.revokeObjectURL(url);
      }
    },
  });
}
