// The part "Expressions" of a card page's box (board "Card page · expressions and 3D figure"): the card's expression
// pack, a line of five of its pictures, its name and how many moods, whose × takes it off the card (with Undo), and
// "+", which opens "Add expressions" (board "Add expressions"): the packs the app holds, one chosen and put on the
// card by "Add", or "From a file…", a zip or the pictures of a folder named by mood, as SillyTavern keeps them, which
// the server keeps once and puts on the card; files dropped on the dialog are taken so too (held-dialog.ts). A card
// has one pack: another takes its place, and the one it had goes to the Trash where no card has it any more (the
// server's).
import { expressionPacks, expressionsFromFiles, expressionUrl, setCardExpressions } from "../api/client";
import type { ExpressionPack } from "../api/generated/ExpressionPack";
import type { Card } from "./card-page";
import { announce, el, lineButton } from "../dom";
import { heldDialog } from "./held-dialog";
import { icon } from "../icons";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";

/** How many of a pack's pictures its line shows. */
const STRIP = 5;
/** The files "From a file…" asks for. */
const PACK_FILES = ".zip,image/png,image/jpeg,image/webp,image/gif";

/** Five of a pack's pictures, side by side. */
const strip = (pack: ExpressionPack) =>
  el("span", { className: "strip" }, ...pack.moods.slice(0, STRIP).map((mood) => el("img", { src: expressionUrl(pack.id, mood), alt: "", title: mood })));

const moodCount = (pack: ExpressionPack) => (wording("card-expressions-moods", { count: pack.moods.length }));

/** The part, its head and its line; `redraw` draws the box anew, with the control it names in focus. */
export function expressionsPart(c: Card, redraw: (focus: string) => void): { tools: HTMLElement[]; rows: HTMLElement[] } {
  const card = c.id!;
  const add = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("card-expressions-add-expressions"), title: wording("card-expressions-add-expressions") }, icon("plus", 16));
  add.onclick = () => void addDialog(c, redraw);
  const pack = c.expressions;
  if (!pack) return { tools: [add], rows: [] };
  const put = (id: number | null) =>
    c.attempt(async () => {
      c.expressions = (await setCardExpressions(card, id)).pack;
      redraw(wording("card-expressions-add-expressions"));
    });
  const takeOff = () =>
    c.attempt(async () => {
      const { before } = await setCardExpressions(card, null);
      c.expressions = null;
      redraw(wording("card-expressions-add-expressions"));
      announce(wording("card-expressions-expressions-removed-from-this"), async () => void (await put(before)));
    });
  const row = el(
    "li",
    { className: "bline row expression-row" },
    el("span", { className: "f-grow flex ai-c g-10" }, strip(pack), el("span", null, pack.name), el("span", { className: "meta" }, wording("card-expressions-pack-moods", { moodCount: moodCount(pack) }))),
    lineButton(wording("card-box-remove-from-this-card-2", { name: pack.name }), wording("card-box-remove-from-this-card"), "close", () => void takeOff()),
  );
  return { tools: [add], rows: [row] };
}

/** "Add expressions": the packs the app holds, one chosen with a press, and the foot's Add, From a file… and Cancel. */
function addDialog(c: Card, redraw: (focus: string) => void): Promise<void> {
  const card = c.id!;
  const given = (pack: ExpressionPack | null) => (c.expressions = pack);
  return heldDialog(c, redraw, {
    title: wording("card-expressions-add-expressions"),
    searched: wording("card-expressions-search-packs"),
    empty: wording("card-expressions-no-expression-packs-yet"),
    accept: PACK_FILES,
    many: true,
    picture: strip,
    about: moodCount,
    current: () => c.expressions?.id ?? null,
    addedTo: () => wording("held-dialog-this-card"),
    held: expressionPacks,
    give: async (id) => given((await setCardExpressions(card, id)).pack),
    fromFiles: async (picked) => {
      const zip = picked.find((file) => file.name.toLowerCase().endsWith(".zip"));
      const name = zip ? zip.name.replace(/\.zip$/i, "") : cardTitle(c.detail?.card.title ?? "");
      return given((await expressionsFromFiles(card, name, picked)).pack);
    },
  });
}
