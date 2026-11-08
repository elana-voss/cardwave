// The character generator (boards "Character generator", "… · writing the card", "… · the card failed"), at
// `#/generator`, opened from the Create menu: one page of sections, 680 px. Looks, a row of pills each, one pick per row (`choice`):
// Gender, Human or not, Age, Build, Hair, Hair colour, each with "Any" first and chosen at opening (`null`, which the
// server picks at random); Personality, sliders between two words, 0 at the first; "How it relates to you", pills,
// at its first pick; Name, typed, or "Random", which fills the field from names fit for the Gender picked (`NAMES`);
// "Make the character" at the foot. Each slider starts in the middle, and a card made without a name is given a
// random one (Claude). A grey line under the title says what comes out; the buttons stay at the window's foot
// (`.form-foot`), and a slider has no fill, its knob in the middle meaning neither word (131a). While the chat model writes (one call, `generateCard`) the picks are greyed in their fieldset, the
// button reads "Writing the character…" and Stop beside it hangs up, which gives the page back as it was; then the new
// card's page opens. A failure stands in red over the button with the picks kept. Leaving the page stops it too.
import { wording } from "../language/language";
import { generateCard } from "../api/client";
import type { Age } from "../api/generated/Age";
import type { Build } from "../api/generated/Build";
import type { Being } from "../api/generated/Being";
import type { Gender } from "../api/generated/Gender";
import type { GeneratorPicks } from "../api/generated/GeneratorPicks";
import type { Hair } from "../api/generated/Hair";
import type { HairColour } from "../api/generated/HairColour";
import type { Relationship } from "../api/generated/Relationship";
import { account } from "../account";
import { el, failure, group, pill, reason, type View } from "../dom";
import { pageTitle } from "../library/list-screen";

/** `true` where the list `L` holds every value of `T`: a value the server adds fails the type check below. */
type Every<T, L extends readonly T[]> = [Exclude<T, L[number]>] extends [never] ? true : false;
const GENDERS = ["Woman", "Man", "Non-binary"] as const satisfies readonly Gender[];
const BEINGS = ["Human", "Not human"] as const satisfies readonly Being[];
const AGES = ["20s", "30s", "40s", "50s and older"] as const satisfies readonly Age[];
const BUILDS = ["Slim", "Average", "Athletic", "Strong"] as const satisfies readonly Build[];
const HAIRS = ["Short", "Medium", "Long"] as const satisfies readonly Hair[];
const COLOURS = ["Black", "Brown", "Blonde", "Red", "Grey", "White"] as const satisfies readonly HairColour[];
const RELATIONSHIPS = ["Stranger", "Friend", "Partner", "Rival", "Colleague", "Mentor"] as const satisfies readonly Relationship[];
true satisfies Every<Gender, typeof GENDERS>;
true satisfies Every<Being, typeof BEINGS>;
true satisfies Every<Age, typeof AGES>;
true satisfies Every<Build, typeof BUILDS>;
true satisfies Every<Hair, typeof HAIRS>;
true satisfies Every<HairColour, typeof COLOURS>;
true satisfies Every<Relationship, typeof RELATIONSHIPS>;

/** How the page words each server value of the picks, by the value. */
const WORDS: Record<Gender | Being | Age | Build | Hair | HairColour | Relationship, () => string> = {
  "Woman": () => wording("gen-gender-woman"),
  "Man": () => wording("gen-gender-man"),
  "Non-binary": () => wording("gen-gender-non-binary"),
  "Human": () => wording("gen-being-human"),
  "Not human": () => wording("gen-being-not-human"),
  "20s": () => wording("gen-age-20s"),
  "30s": () => wording("gen-age-30s"),
  "40s": () => wording("gen-age-40s"),
  "50s and older": () => wording("gen-age-50s-and-older"),
  "Slim": () => wording("gen-build-slim"),
  "Average": () => wording("gen-build-average"),
  "Athletic": () => wording("gen-build-athletic"),
  "Strong": () => wording("gen-build-strong"),
  "Short": () => wording("gen-hair-short"),
  "Medium": () => wording("gen-hair-medium"),
  "Long": () => wording("gen-hair-long"),
  "Black": () => wording("gen-colour-black"),
  "Brown": () => wording("gen-colour-brown"),
  "Blonde": () => wording("gen-colour-blonde"),
  "Red": () => wording("gen-colour-red"),
  "Grey": () => wording("gen-colour-grey"),
  "White": () => wording("gen-colour-white"),
  "Stranger": () => wording("gen-relation-stranger"),
  "Friend": () => wording("gen-relation-friend"),
  "Partner": () => wording("gen-relation-partner"),
  "Rival": () => wording("gen-relation-rival"),
  "Colleague": () => wording("gen-relation-colleague"),
  "Mentor": () => wording("gen-relation-mentor"),
};
/** The sliders: the picks' key and the two words, the first at 0. */
const SLIDERS = [
  ["shy_outgoing", () => wording("gen-shy"), () => wording("gen-outgoing")],
  ["gentle_harsh", () => wording("gen-gentle"), () => wording("gen-harsh")],
  ["serious_playful", () => wording("gen-serious"), () => wording("gen-playful")],
  ["cautious_bold", () => wording("gen-cautious"), () => wording("gen-bold")],
] as const;

/** First names by the Gender picked, and last names for all. */
const NAMES = {
  Woman: ["Amanda", "Ana", "Camila", "Chloe", "Elena", "Emily", "Grace", "Hannah", "Isabella", "Julia", "Lucia", "Maya", "Naomi", "Nina", "Olivia", "Rose", "Ruby", "Sofia", "Vivian", "Yuki"],
  Man: ["Adrian", "Ben", "Carlos", "Daniel", "Elias", "Felix", "Gabriel", "Hugo", "Ivan", "James", "Kenji", "Leo", "Marco", "Noah", "Omar", "Owen", "Rafael", "Samuel", "Theo", "Victor"],
  Other: ["Alex", "Ash", "Avery", "Blake", "Eden", "Jordan", "Kai", "Morgan", "Noor", "Quinn", "Remy", "River", "Robin", "Rowan", "Sage", "Sam", "Skyler", "Taylor", "Wren", "Zephyr"],
  last: ["Bennett", "Brooks", "Carter", "Chen", "Cruz", "Foster", "Harper", "Kim", "Lopez", "Moore", "Nakamura", "Nguyen", "Park", "Reed", "Rivera", "Stone", "Torres", "Turner", "Walker", "Wong"],
};

const any = <T>(list: T[]): T => list[Math.floor(Math.random() * list.length)]!;

/** A random first and last name, the first fit for `gender` (one for anyone where it is "Any" or Non-binary). */
const randomName = (gender: Gender | null) => `${any(gender === "Woman" || gender === "Man" ? NAMES[gender] : NAMES.Other)} ${any(NAMES.last)}`;

/** A row of pills of which one is picked: `value` at first, each press handed to `set`. */
function choice<T extends keyof typeof WORDS>(label: string, options: readonly T[], value: T, set: (picked: T) => void): HTMLElement {
  return pills(label, options.map((option) => [WORDS[option](), option] as const), value, set);
}

/** A row of `choice` with "Any" (`null`) first, chosen at opening. */
function anyChoice<T extends keyof typeof WORDS>(label: string, options: readonly T[], set: (picked: T | null) => void): HTMLElement {
  return pills<T | null>(label, [[wording("gen-any"), null], ...options.map((option) => [WORDS[option](), option] as const)], null, set);
}

/** The pills of `options` (each its word and value), `value`'s pressed, each press handed to `set`. */
function pills<T>(label: string, options: readonly (readonly [string, T])[], value: T, set: (picked: T) => void): HTMLElement {
  const row = options.map(([word, option]) =>
    pill(word, option === value, () => {
      row.forEach((one, at) => (one.ariaPressed = String(options[at]![1] === option)));
      set(option);
    }),
  );
  return el("div", { className: "pills", role: "group", ariaLabel: label }, ...row);
}

/** A labelled row of `choice`. */
const field = (label: string, row: HTMLElement) => el("div", { className: "fld" }, el("span", { className: "label" }, label), row);

export function generatorView(): View {
  const picks: GeneratorPicks = {
    gender: null,
    being: null,
    age: null,
    build: null,
    hair: null,
    hair_colour: null,
    shy_outgoing: 50,
    gentle_harsh: 50,
    serious_playful: 50,
    cautious_bold: 50,
    relationship: RELATIONSHIPS[0]!,
    name: "",
    creator: "",
  };
  const name = el("input", { type: "text", className: "field f-grow", ariaLabel: wording("common-name"), placeholder: wording("common-name"), maxLength: 100 });
  const random = el("button", { type: "button", className: "btn btn-secondary", onclick: () => void (name.value = randomName(picks.gender)) }, wording("gen-random"));
  const sliders = SLIDERS.map(([key, lowWord, highWord]) => {
    const [low, high] = [lowWord(), highWord()];
    const slider = el("input", { type: "range", min: "0", max: "100", value: "50", ariaLabel: wording("gen-slider", { low, high }) });
    slider.addEventListener("input", () => (picks[key] = Number(slider.value)));
    return el("div", { className: "sl" }, el("span", null, low), slider, el("span", null, high));
  });
  const fieldset = el(
    "fieldset",
    { className: "gen-picks flex f-col g-32" },
    group(
      wording("gen-looks"),
      null,
      el(
        "div",
        { className: "flex f-col g-16" },
        field(wording("gen-gender"), anyChoice(wording("gen-gender"), GENDERS, (gender) => (picks.gender = gender))),
        field(wording("gen-being"), anyChoice(wording("gen-being"), BEINGS, (being) => (picks.being = being))),
        field(wording("gen-age"), anyChoice(wording("gen-age"), AGES, (age) => (picks.age = age))),
        field(wording("gen-build"), anyChoice(wording("gen-build"), BUILDS, (build) => (picks.build = build))),
        field(wording("gen-hair"), anyChoice(wording("gen-hair"), HAIRS, (hair) => (picks.hair = hair))),
        field(wording("gen-hair-colour"), anyChoice(wording("gen-hair-colour"), COLOURS, (colour) => (picks.hair_colour = colour))),
      ),
    ),
    group(wording("gen-personality"), null, el("div", { className: "flex f-col g-14" }, ...sliders)),
    group(wording("gen-relates"), null, choice(wording("gen-relates"), RELATIONSHIPS, picks.relationship, (relationship) => (picks.relationship = relationship))),
    group(wording("common-name"), null, el("div", { className: "flex g-8" }, name, random)),
  );
  const why = el("div");
  const make = el("button", { type: "button", className: "btn btn-primary" }, wording("gen-make"));
  const stop = el("button", { type: "button", className: "btn btn-secondary", hidden: true }, wording("gen-stop"));
  let writing: AbortController | null = null;

  /** The page as it is while the card is written, or given back. */
  function busy(now: boolean): void {
    fieldset.disabled = make.disabled = now;
    make.textContent = now ? wording("gen-writing") : wording("gen-make");
    stop.hidden = !now;
  }

  make.onclick = async () => {
    if (!name.value.trim()) name.value = randomName(picks.gender);
    writing = new AbortController();
    const mine = writing;
    why.replaceChildren();
    busy(true);
    try {
      picks.creator = await account().then(({ name }) => name, () => "");
      const made = await generateCard({ ...picks, name: name.value.trim() }, mine.signal);
      location.hash = `#/library/${made.card_id}`;
    } catch (error) {
      if (!mine.signal.aborted) why.replaceChildren(failure(reason(error)));
    } finally {
      if (writing === mine) {
        writing = null;
        busy(false);
      }
    }
  };
  stop.onclick = () => writing?.abort();

  const node = el(
    "section",
    { className: "main" },
    el("header", { className: "pbar" }, pageTitle(wording("page-generator"))),
    el("div", { className: "page-col mt-12" }, el("p", { className: "hint" }, wording("gen-what")), fieldset, why),
    el("div", { className: "form-foot flex g-8" }, make, stop),
  );
  return { node: node, left: () => writing?.abort() };
}
