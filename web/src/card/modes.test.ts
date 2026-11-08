// The modes of a card and a chat, without a browser: which mode a chat is in and how its pill says it, which
// modes are personal, a text's name and mode tag, and a change of the card's modes made in all its texts.
import { expect, test } from "vitest";
import type { CardEdit } from "../api/generated/CardEdit";
import type { Chat } from "../api/generated/Chat";
import type { EditText } from "../api/generated/EditText";
import { firstMode, isPersonal, modeInUse, modeLabel, modeTag, pressMode, removeMode, renameMode, textName, usedIn } from "./modes";

const MODES = ["Roleplay", "Assistant"];
const chat = (mode: string | null, auto_mode: string | null) => ({ mode, auto_mode }) as Chat;

test("a chat is in the mode set by hand, else the one it picked, else its card's first", () => {
  expect(modeInUse(chat(null, null), MODES)).toBe("Roleplay");
  expect(modeInUse(chat(null, "assistant"), MODES)).toBe("Assistant");
  expect(modeInUse(chat("roleplay", "Assistant"), MODES)).toBe("Roleplay");
  expect(modeInUse(chat("Gone", "Also gone"), MODES)).toBe("Roleplay");
  expect(modeInUse(chat(null, null), [])).toBeNull();
  expect(modeLabel(chat(null, "Assistant"), MODES)).toBe("Assistant · automatic");
  expect(modeLabel(chat("Assistant", null), MODES)).toBe("Assistant");
  expect(modeLabel(chat("Gone", null), MODES)).toBe("Roleplay · automatic");
  expect([isPersonal("ASSISTANT"), isPersonal("Companion"), isPersonal("Roleplay"), isPersonal(null)]).toEqual([true, true, false, false]);
});

test("a text's tag says its modes, and a change of the card's modes is made in its texts, its greetings and prompts too", () => {
  const part = (modes?: string[]): EditText => ({ reference: "personality.x", text: "", modes });
  expect(textName("Personality", part(["Roleplay"]), true)).toBe("Personality · personality.x");
  expect(textName("Personality", part([]), false)).toBe("Personality");
  expect([modeTag(part()), modeTag(part(["Roleplay"])), modeTag(part(["Roleplay", "Companion"]))]).toEqual(["All modes", "Roleplay only", "Roleplay, Companion"]);
  expect([usedIn(part(), "Roleplay"), usedIn(part(["roleplay"]), "Roleplay"), usedIn(part(["Assistant"]), "Roleplay"), usedIn(part(["Assistant"]), null)]).toEqual([true, true, false, true]);

  const scene = part(["Roleplay"]);
  const both = part(["Roleplay", "Assistant"]);
  const prompt = part(["Roleplay"]);
  const greeting = part(["Roleplay"]);
  const edit = {
    modes: ["Roleplay", "Assistant"],
    characters: [{ greetings: [greeting], group_greetings: [], description: [both], personality: [scene], scenario: [], example_dialogue: [], system_prompt: [], post_history: [], depth_prompts: [{ ...prompt, depth: 4 }] }],
  } as unknown as CardEdit;
  renameMode(edit, "roleplay", " Story ");
  expect([edit.modes, scene.modes, both.modes, greeting.modes, edit.characters[0].depth_prompts[0].modes]).toEqual([["Story", "Assistant"], ["Story"], ["Story", "Assistant"], ["Story"], ["Story"]]);
  firstMode(edit, "assistant");
  expect(edit.modes).toEqual(["Assistant", "Story"]);
  removeMode(edit, "Story");
  expect([edit.modes, scene.modes, both.modes]).toEqual([["Assistant"], [], ["Assistant"]]);

  // A mode pressed is taken in or out; a text in every mode of the card is in all of them.
  const modes = ["Roleplay", "Assistant", "Companion"];
  pressMode(scene, "Roleplay", modes);
  expect(scene.modes).toEqual(["Roleplay"]);
  pressMode(scene, "Assistant", modes);
  expect(scene.modes).toEqual(["Roleplay", "Assistant"]);
  pressMode(scene, "companion", modes);
  expect(scene.modes).toEqual([]);
  pressMode(both, "assistant", ["Assistant"]);
  expect(both.modes).toEqual([]);
  pressMode(both, null, modes);
  expect(both.modes).toEqual([]);
});
