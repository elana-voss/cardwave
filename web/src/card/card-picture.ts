// The card's picture at the head of its page (boards "Card's picture", "Make a picture", "Earlier pictures"):
// `heroPicture` draws it. A click picks a file, and a file dropped anywhere on the page replaces it (the picture
// says "Drop to use this picture" while one is dragged over the page); pointed at, the picture shows "Make a
// picture" and "Earlier pictures" (only where the card has had a picture). A card without art shows the empty picture, with "Make a picture". No picture
// is ever thrown away: each change says "Picture changed." with Undo, which shows the one before.
//
// A new card not made yet keeps the file chosen (`Card.pending`) until it is made with it (card-page.ts); "Make a
// picture" cannot be pressed until then. Traps: a change waits for the saves before it (`after`), as it gives the
// card a new version; the page is read anew after it, and the picture drawn anew even while a text is written
// (`redraw`). The picture is the card's own, never a character's avatar among its files.
import { cardImageUrl, cardPictures, cardPictureUrl, getImages, makeCardPicture, pictureFromFile, pictureWords, useCardPicture } from "../api/client";
import type { CardPicture } from "../api/generated/CardPicture";
import type { PictureChanged } from "../api/generated/PictureChanged";
import { after, load, type Card } from "./card-page";
import { announce, el, fileField, hasFiles, noticeBox, oneAtATime, TOUCH } from "../dom";
import { isArt, PICTURES } from "../art";
import { dialog } from "../dialogs";
import { dayMonth } from "../format";
import { icon } from "../icons";
import { wording } from "../language/language";

/** How long after the last `dragover` the page counts a file as no longer dragged over it. */
const DRAG_GONE_MS = 150;
/** The most characters of what a picture shows, as the server takes them. */
const MAX_WORDS = 1000;

/** What each source is called in "Earlier pictures". */
/** What the picture's place says it does: a touch screen taps and drops nothing (Claude). */
export const choosing = (touch = TOUCH.matches) =>
  touch
    ? { label: wording("card-picture-card-picture-tap-to"), says: wording("card-picture-tap-to-choose") }
    : { label: wording("card-picture-card-picture-click-to"), says: wording("card-picture-click-or-drop-a") };

const cameFrom = (): Record<CardPicture["source"], string> => ({ imported: wording("importing-imported"), file: wording("card-picture-from-a-file"), made: wording("card-picture-made") });

/** The card's picture, with what changes it. */
export function heroPicture(c: Card): HTMLElement {
  const card = c.detail?.card;
  const src = card ? cardImageUrl(card.version_id) : c.pending ? URL.createObjectURL(c.pending) : null;
  const node = el("div", { className: "hero-img hero-picture pic", role: "group", ariaLabel: wording("card-picture-card-picture") });
  const field = fileField(c.node, PICTURES.join(","), false, ([file]) => {
    node.classList.remove("dropping");
    if (file) choose(c, file);
  });
  const pick = el("button", { type: "button", className: "pic-choose", ariaLabel: choosing().label, onclick: () => field.click() });
  const made = c.id !== null;
  // Grey until the card is made, and why.
  const waits = made ? undefined : wording("card-picture-name-first");
  const make = el("button", { type: "button", className: "rbtn", disabled: !made, title: waits, onclick: () => void makeDialog(c) }, icon("picture", 16), wording("card-picture-make-a-picture"));
  // A card not made yet has had no other picture; a made one offers them once it is known to have had one.
  const earlier = made && el("button", { type: "button", className: "rbtn", hidden: true, onclick: () => void earlierDialog(c) }, icon("clock", 16), wording("card-picture-earlier-pictures"));
  const blankMake = el("button", { type: "button", className: "btn btn-secondary on-box", disabled: !made, title: waits, onclick: () => void makeDialog(c) }, icon("picture", 16), wording("card-picture-make-a-picture"));
  // A card made that shows none may have had pictures: they are brought back as from a picture (Claude).
  const blankEarlier = made && el("button", { type: "button", className: "btn btn-secondary on-box", hidden: true, onclick: () => void earlierDialog(c) }, icon("clock", 16), wording("card-picture-earlier-pictures"));
  node.append(
    field,
    pick,
    el("div", { className: "pic-ov" }, el("p", null, choosing().says), el("div", { className: "rbtns" }, make, earlier)),
    el("div", { className: "pic-empty pic-blank" }, icon("picture", 28), el("span", null, choosing().says), blankMake, blankEarlier),
    el("div", { className: "pic-drop" }, wording("card-picture-drop-to-use-this")),
  );
  if (c.id !== null && earlier && blankEarlier) {
    void cardPictures(c.id)
      .then((pictures) => {
        earlier.hidden = blankEarlier.hidden = !pictures.length;
      })
      // Not read, the buttons stay away: the picture itself works without them.
      .catch(() => undefined);
  }
  if (src) {
    const picture = el("img", { src, alt: "" });
    picture.onload = () => {
      if (!card) URL.revokeObjectURL(src);
      node.classList.toggle("empty", !isArt(picture));
    };
    picture.onerror = () => {
      if (!card) URL.revokeObjectURL(src);
      node.classList.add("empty");
    };
    node.prepend(picture);
  } else node.classList.add("empty");
  return node;
}

/** Has the picture say that it takes a file while one is dragged over the page, until none has been for a moment. Called once per page. */
export function watchDrags(c: Card): void {
  let gone = 0;
  c.node.addEventListener("dragover", (event) => {
    const picture = c.body.querySelector(".hero-picture");
    if (!picture || !hasFiles(event)) return;
    picture.classList.add("dropping");
    clearTimeout(gone);
    gone = window.setTimeout(() => picture.classList.remove("dropping"), DRAG_GONE_MS);
  });
}

/** Draws the picture anew, where the page was not drawn anew after a change (a text was being written). */
function redraw(c: Card): void {
  c.body.querySelector(".hero-picture")?.replaceWith(heroPicture(c));
}

/** Reads the card anew after its picture changed, and says so, with Undo showing the one before. */
async function changed(c: Card, change: PictureChanged): Promise<void> {
  await load(c);
  redraw(c);
  const id = c.id;
  if (id === null) return;
  announce(wording("profile-picture-changed"), () =>
    after(c, async () => {
      await useCardPicture(id, change.before);
      await load(c);
      redraw(c);
    }),
  );
}

/** Makes the file the card's picture; a new card not made yet keeps it until it is. */
function choose(c: Card, file: File): void {
  void after(c, async () => {
    // A file the system names no type of is left to the server, which reads what it is.
    if (file.type && !PICTURES.includes(file.type)) throw new Error(wording("art-is-not-a-png", { name: file.name }));
    if (c.id === null) {
      c.pending = file;
      redraw(c);
      return;
    }
    await changed(c, await pictureFromFile(c.id, file));
  });
}

/** Has the card show `picture`, of its own, when the saves before are done. */
function show(c: Card, picture: number): Promise<void> {
  return after(c, async () => {
    if (c.id !== null) await changed(c, await useCardPicture(c.id, picture));
  });
}

/** The foot of a dialog: its buttons, the main one first and Cancel last, which closes it. */
function foot(box: () => HTMLDialogElement, ...buttons: HTMLButtonElement[]): HTMLElement {
  // One look for a dialog's Cancel: the grey button (v5).
  const cancel = el("button", { type: "button", className: "btn btn-secondary", onclick: () => box().close() }, wording("common-cancel"));
  return el("div", { className: "dfoot" }, ...buttons, cancel);
}

/** How long the background model has to write what the picture shows; "card-picture-no-answer" names it. */
const WORDS_WAIT = 30_000;

/**
 * "Make a picture": the background model reads the whole card and writes what the picture shows, then the image
 * model draws it; each picture made joins the card's pictures, and "Use this picture" shows the one in view.
 * Without an image model it says to set one up first.
 */
async function makeDialog(c: Card): Promise<void> {
  const id = c.id;
  if (id === null) return;
  const model = await getImages().catch(() => null);
  if (!model) {
    let box: HTMLDialogElement | null = null;
    box = dialog(
      c.node,
      wording("card-picture-make-a-picture"),
      el("p", { className: "m0" }, wording("card-picture-set-up-an-image"), el("a", { href: "#/settings" }, wording("card-picture-settings-models")), "."),
      foot(() => box!),
    );
    box.classList.add("make-picture-dialog");
    return;
  }
  const words = el("textarea", { className: "field", id: "make-words", rows: 10, maxLength: MAX_WORDS });
  const hint = el("p", { className: "hint" });
  const frame = el("div", { className: "made-frame" });
  const back = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("card-picture-previous-picture"), title: wording("card-picture-previous-picture") }, icon("left", 16));
  const next = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("card-picture-next-picture"), title: wording("card-picture-next-picture") }, icon("right", 16));
  const count = el("span", { className: "meta" });
  const steps = el("div", { className: "flex ai-c g-4" }, back, count, next);
  const use = el("button", { type: "button", className: "btn btn-primary" }, wording("card-picture-use-this-picture"));
  const another = el("button", { type: "button", className: "btn btn-secondary" }, wording("card-picture-make-another-picture"));
  const again = el("button", { type: "button", className: "btn btn-secondary" }, wording("card-picture-write-the-description-again"));
  const why = noticeBox();
  const box = dialog(
    c.node,
    wording("card-picture-make-a-picture"),
    el(
      "div",
      { className: "flex g-24" },
      el("div", { className: "made-side flex f-col g-8 ai-c" }, frame, steps),
      el("div", { className: "f-grow minw0 flex f-col g-10" }, el("div", { className: "fld" }, el("label", { className: "label", htmlFor: words.id }, wording("card-picture-what-the-picture-shows")), words), hint),
    ),
    why,
    foot(() => box, use, another, again),
  );
  box.classList.add("make-picture-dialog");
  const attempt = oneAtATime(why);
  const made: CardPicture[] = [];
  let at = 0;
  let busy: "reading" | "making" | null = null;
  const draw = () => {
    const picture = made[at];
    frame.replaceChildren(busy === "making" ? el("span", null, wording("card-picture-making-a-picture")) : picture ? el("img", { src: cardPictureUrl(id, picture.id), alt: wording("card-picture-the-picture-made") }) : "");
    frame.classList.toggle("waiting", busy === "making" || !picture);
    steps.hidden = made.length < 2;
    count.textContent = wording("card-picture-of", { at: at + 1, count: made.length });
    back.disabled = !!busy || at === 0;
    next.disabled = !!busy || at >= made.length - 1;
    words.disabled = busy === "reading";
    words.placeholder = busy === "reading" ? wording("card-picture-reading-the-card") : "";
    use.disabled = !!busy || !picture;
    another.disabled = !!busy || !words.value.trim();
    again.disabled = !!busy;
  };
  words.oninput = draw;
  back.onclick = () => ((at = Math.max(0, at - 1)), draw());
  next.onclick = () => ((at = Math.min(made.length - 1, at + 1)), draw());
  const working = (state: "reading" | "making", step: () => Promise<void>) =>
    attempt(async () => {
      busy = state;
      draw();
      try {
        await step();
      } finally {
        busy = null;
        if (box.open) draw();
      }
    });
  const write = () =>
    working("reading", async () => {
      words.value = "";
      // A provider that never answers would leave "Reading the card…" for minutes: after WORDS_WAIT the request
      // is given up and the dialog says so, with "again" free. A timer, not AbortSignal.timeout, which the
      // browser tests' clock cannot hurry.
      const giveUp = new AbortController();
      const timer = setTimeout(() => giveUp.abort(), WORDS_WAIT);
      const written = await pictureWords(id, giveUp.signal)
        .catch((error: unknown) => {
          throw giveUp.signal.aborted ? new Error(wording("card-picture-no-answer")) : error;
        })
        .finally(() => clearTimeout(timer));
      if (!box.open) return;
      words.value = written.words;
      // A program on this computer comes unnamed; the sentence then says so in its own words.
      hint.textContent = written.provider ? wording("card-picture-drawn-by", { provider: written.provider }) : wording("card-picture-drawn-here");
    });
  const paint = () =>
    working("making", async () => {
      const picture = await makeCardPicture(id, words.value);
      made.push(picture);
      at = made.length - 1;
    });
  again.onclick = () => void write();
  another.onclick = () => void paint();
  use.onclick = () => {
    const picture = made[at];
    if (!picture) return;
    box.close();
    void show(c, picture.id);
  };
  draw();
  // First the words, then a picture of them.
  if (await write()) await paint();
}

/** The day a picture came to the card, as "Earlier pictures" says it: "Today", else "12 Oct" (and the year where it is another). */
const cameOn = (at: number) => dayMonth(at);

/** "Earlier pictures": every picture the card had, newest first, one chosen and shown with "Use this picture". */
async function earlierDialog(c: Card): Promise<void> {
  const id = c.id;
  if (id === null) return;
  const why = noticeBox();
  const use = el("button", { type: "button", className: "btn btn-primary", disabled: true }, wording("card-picture-use-this-picture"));
  const tiles = el("div", { className: "thumbs" });
  const box = dialog(c.node, wording("card-picture-earlier-pictures"), tiles, why, foot(() => box, use));
  box.classList.add("earlier-dialog");
  let chosen: CardPicture | null = null;
  const attempt = oneAtATime(why);
  await attempt(async () => {
    const pictures = await cardPictures(id);
    if (!pictures.length) tiles.replaceWith(el("p", { className: "meta" }, wording("card-picture-no-earlier-pictures")));
    tiles.replaceChildren(
      ...pictures.map((picture) => {
        const tile = el(
          "button",
          { type: "button", className: "thumb", ariaPressed: "false" },
          el("img", { src: cardPictureUrl(id, picture.id), alt: "" }),
          el("span", { className: "meta" }, wording("card-picture-tile", { came: picture.in_use ? wording("card-picture-in-use") : cameFrom()[picture.source], on: cameOn(picture.added_at) })),
        );
        tile.onclick = () => {
          chosen = picture;
          for (const one of tiles.children) one.setAttribute("aria-pressed", String(one === tile));
          use.disabled = picture.in_use;
        };
        return tile;
      }),
    );
  });
  use.onclick = () => {
    if (!chosen) return;
    box.close();
    void show(c, chosen.id);
  };
}
