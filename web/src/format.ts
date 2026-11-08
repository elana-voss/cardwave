// What is written how: a moment (`ago`, `daysLeft`, `day`, `dayMonth`, `dayAt`, `moment`, `dateTime`, `clock`, a day `DAY_MS`), a number
// (`count`, `decimal`), a file's size (`bytes`), a folder's long path cut in the middle (`folderShort`), the comma in a row of names (`comma`), names joined with "and" (`names`), the first sign of a name (`initialOf`), and a code name as words
// (`spoken`). Every date and number the UI shows is written here, in the language in use (`written`): English in the
// forms the boards draw, each its own ("12 Oct", "Oct 12, 2026, 9:10 PM"), never the computer's.
import { language, wording } from "./language/language";

export const DAY_MS = 86_400_000;

/** The days left before what is in the Trash is deleted for good `at`: counted from the moment it came, so on its last day one is left. */
export const daysLeft = (at: number) => Math.max(1, Math.ceil((at - Date.now()) / DAY_MS));

/** The locale a form is written in: the language in use, English as `english` names its form. */
const written = (english: string) => (language() === "en" ? english : language());

/** A whole number, grouped: "1,234". */
export const count = (n: number) => n.toLocaleString(written("en-US"));

/** A number to `places` places behind the point: "0.4". */
export const decimal = (n: number, places: number) =>
  n.toLocaleString(written("en-US"), { minimumFractionDigits: places, maximumFractionDigits: places });

/** The language's own comma between names or tags in a row: ", ", in Japanese "、". */
export const comma = () => wording("format-comma");

/** Names in a row as the language joins them: "Mira and you", "Noor, Sam, and you". */
export const names = (all: string[]) => new Intl.ListFormat(written("en"), { type: "conjunction" }).format(all);

/** The first sign of a name, whole and in upper case: what stands in the round of an account or a persona. */
export const initialOf = (name: string) => ([...name.trim()][0] ?? "").toUpperCase();

/** A code name as words: "word_count", "dice-roll" or "daysBetween" as "Word count", "Dice roll", "Days between". */
export function spoken(name: string): string {
  const words = name
    .replace(/([a-z\d])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .trim()
    .toLowerCase();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/** How long ago `at` was, in whole calendar days: "Today", "Yesterday", "3 days ago", "1 week ago", "5 months ago", "1 year ago". */
export function ago(at: number | null, now = Date.now()): string {
  if (at === null) return "—";
  const day = (time: number) => {
    const date = new Date(time);
    return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / DAY_MS;
  };
  const days = day(now) - day(at);
  if (days <= 0) return wording("format-today");
  if (days === 1) return wording("format-yesterday");
  if (days < 7) return wording("format-days-ago", { count: days });
  if (days < 60) return wording("format-weeks-ago", { count: Math.floor(days / 7) });
  if (days < 365) return wording("format-months-ago", { count: Math.floor(days / 30) });
  return wording("format-years-ago", { count: Math.floor(days / 365) });
}

/**
 * How a size in bytes is written: in KB, MB or GB of 1024 each, as Windows writes a file's, in whole KB, of which a
 * part counts as one, and from 1000 of them on with one place behind the point.
 */
export function bytes(size: number): string {
  const kb = Math.ceil(size / 1024);
  if (kb < 1000) return wording("format-kb", { kb });
  const mb = size / 1024 ** 2;
  return mb < 999.95 ? wording("format-mb", { mb }) : wording("format-gb", { gb: mb / 1024 });
}

/** A day as the card's lists write it (boards "Text versions", "Earlier pictures"): "Today", else "12 Oct", the year only where it is another ("12 Oct 2025"). */
export function dayMonth(at: number, now = Date.now()): string {
  const when = new Date(at);
  const today = new Date(now);
  if (when.toDateString() === today.toDateString()) return wording("format-today");
  const year = when.getFullYear() === today.getFullYear() ? {} : { year: "numeric" as const };
  return when.toLocaleDateString(written("en-GB"), { day: "numeric", month: "short", ...year });
}

/** A moment as a text's versions write it: its day as `dayMonth` and its 24 h clock, "Today, 14:02", "12 Oct, 21:10". */
export const dayAt = (at: number, now = Date.now()) =>
  wording("format-day-at", { day: dayMonth(at, now), time: new Date(at).toLocaleTimeString(written("en-GB"), { hour: "2-digit", minute: "2-digit" }) });

/** The day of the moment `at`: when a version of a card was made, "12 Oct 2026", British as the app spells. */
export const day = (at: number) => new Date(at).toLocaleDateString(written("en-GB"), { day: "numeric", month: "short", year: "numeric" });

/** The moment `at` in full, for where [`ago`] is too short: "10/12/2026, 9:10:00 PM". */
export const moment = (at: number | null) => (at === null ? wording("team-audit-never") : new Date(at).toLocaleString(written("en-US")));

/** The time of day of the moment `at`: a coding task's checkpoint, "09:10 PM". */
export const clock = (at: number) => new Date(at).toLocaleTimeString(written("en-US"), { hour: "2-digit", minute: "2-digit" });

/** When a coding task began, as its board writes it: "Jan 1, 2026, 12:00 PM". */
export const dateTime = (at: number) =>
  new Date(at).toLocaleString(written("en-US"), { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" });

/** A folder's path with its start and its own name and the middle cut ("C:\\Users\\…\\Documents"), where it has more than four parts. */
export function folderShort(path: string): string {
  // A start of separators ("/", a share's "\\\\") is kept whole; one at the end is no part.
  const lead = /^[\\/]*/.exec(path)![0];
  const parts = path.slice(lead.length).split(/[\\/]+/).filter(Boolean);
  if (parts.length + (lead ? 1 : 0) <= 4) return path;
  const sign = path.includes("\\") ? "\\" : "/";
  return lead + [...parts.slice(0, lead ? 1 : 2), "…", parts[parts.length - 1]].join(sign);
}

/** A reason or failure put inside a sentence of the app's ("The test failed: { $failed }. Check …"): its own full stop dropped, an ellipsis kept. */
export const clause = (text: string) => text.replace(/(?<!\.)\.\s*$/, "");
