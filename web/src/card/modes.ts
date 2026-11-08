// A card's modes as the card's page and a chat show them (the server's assistant.rs): the mode a chat is in
// (`modeInUse`) and how its header's pill says it (`modeLabel`); whether a character in it goes by its
// personality (`isPersonal`); on the card's page a text's name (`textName`), whether it is used in a mode
// (`usedIn`), its mode tag (`modeTag`) and what its menu does to it (`pressMode`), and a change of the card's
// modes made in all its texts at once (`addedMode`, `renameMode`, `removeMode`, `firstMode`). Modes are one whatever their
// case, as on the server.
import type { CardEdit } from "../api/generated/CardEdit";
import type { Chat } from "../api/generated/Chat";
import type { EditText } from "../api/generated/EditText";
import type { Tool } from "../api/generated/Tool";
import { wording } from "../language/language";
import { comma } from "../format";

/** Whether two modes are one. */
export const sameMode = (one: string, other: string) => one.trim().toLowerCase() === other.trim().toLowerCase();

/** The mode the chat is in: the one set by hand, else the one it picked last, else its card's first; none without modes. */
export function modeInUse(chat: Chat, modes: string[]): string | null {
  for (const wanted of [chat.mode, chat.auto_mode]) {
    const mode = wanted === null ? undefined : modes.find((one) => sameMode(one, wanted));
    if (mode) return mode;
  }
  return modes[0] ?? null;
}

/** What the chat's pill says: the mode in use, and "automatic" while the chat picks by itself. */
export function modeLabel(chat: Chat, modes: string[]): string {
  const mode = modeInUse(chat, modes) ?? "";
  const byHand = chat.mode !== null && modes.some((one) => sameMode(one, chat.mode ?? ""));
  return byHand ? mode : wording("modes-automatic", { mode });
}

/** Whether a character in the mode goes by its personality: in Assistant and Companion. */
export const isPersonal = (mode: string | null) => mode !== null && (sameMode(mode, "assistant") || sameMode(mode, "companion"));

/** The tools a personality may use, as the side panel names them. */
export const toolNames = (): Record<Tool, string> => ({
  web: wording("label-settings-web"),
  files: wording("label-settings-files"),
  commands: wording("label-settings-commands"),
  pictures: wording("modes-pictures"),
  code: wording("modes-let-the-ai-write"),
  coding: wording("modes-coding-tasks"),
  cardwave: wording("app-name"),
});

/** A note's name, by how many messages back it stands: "Note, 4 messages back". */
export const noteName = (depth: number) => wording("modes-note", { depth });

/** A greeting's name in a group chat, numbered where the character has several. */
export const groupGreetingName = (at: number, several: boolean) => (several ? wording("modes-group-chat-greeting-2", { at: at + 1 }) : wording("modes-group-chat-greeting"));

/** A text's name on the card's page: where its kind has several texts in view, with its block. */
export const textName = (name: string, part: EditText, several: boolean) => (several && part.reference ? `${name} · ${part.reference}` : name);

/** Whether a text is used in `mode`: one used in all modes is, and every text is where the card has none (`null`). */
export const usedIn = (part: EditText, mode: string | null) => mode === null || !part.modes?.length || part.modes.some((one) => sameMode(one, mode));

/** What a text's mode tag says, in its menu's words: "All modes", "Roleplay only", or the modes it is used in. */
export function modeTag(part: EditText): string {
  const modes = part.modes ?? [];
  if (!modes.length) return wording("card-modes-all-modes");
  return modes.length === 1 ? wording("card-modes-only", { one: modes[0] }) : modes.join(comma());
}

/** Every text of the card that can name modes, of all its characters. */
const texts = (edit: CardEdit): EditText[] =>
  edit.characters.flatMap((one) => [
    ...one.greetings,
    ...one.group_greetings,
    ...one.description,
    ...one.personality,
    ...one.scenario,
    ...one.example_dialogue,
    ...one.system_prompt,
    ...one.post_history,
    ...one.depth_prompts,
  ]);

/** Renames a mode of the card, in the card and in every text used in it. */
export function renameMode(edit: CardEdit, mode: string, to: string): void {
  const name = (one: string) => (sameMode(one, mode) ? to.trim() : one);
  edit.modes = (edit.modes ?? []).map(name);
  for (const part of texts(edit)) if (part.modes) part.modes = part.modes.map(name);
}

/** Takes a mode off the card and off every text; a text that was used in it alone is used in all then. */
export function removeMode(edit: CardEdit, mode: string): void {
  edit.modes = (edit.modes ?? []).filter((one) => !sameMode(one, mode));
  for (const part of texts(edit)) if (part.modes) part.modes = part.modes.filter((one) => !sameMode(one, mode));
}

/**
 * Adds the mode `name` to the card. The first one added makes two: the card's texts stay its own as the default
 * mode `first`, and `name` beside it has its own texts to write.
 */
export function addedMode(edit: CardEdit, name: string, first: string): void {
  const modes = edit.modes ?? [];
  if (!modes.length) for (const part of texts(edit)) part.modes = [first];
  edit.modes = modes.length ? [...modes, name] : [first, name];
}

/** Makes a mode the card's first, the one a chat begins in. */
export function firstMode(edit: CardEdit, mode: string): void {
  const modes = edit.modes ?? [];
  edit.modes = [...modes.filter((one) => sameMode(one, mode)), ...modes.filter((one) => !sameMode(one, mode))];
}

/**
 * A text's modes after a press on a line of its tag's menu (`null`: "All modes"): all of them, or the pressed one
 * taken in or out; a text in each of the card's modes `all` is in all modes.
 */
export function pressMode(part: EditText, mode: string | null, all: string[]): void {
  const modes = part.modes ?? [];
  if (mode === null) part.modes = [];
  else part.modes = modes.some((one) => sameMode(one, mode)) ? modes.filter((one) => !sameMode(one, mode)) : [...modes, mode];
  if (all.every((one) => part.modes!.some((other) => sameMode(one, other)))) part.modes = [];
}
