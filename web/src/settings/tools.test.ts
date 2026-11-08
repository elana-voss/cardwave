// The lines of the settings' group Tools.
import { expect, test } from "vitest";
import { toolLines, writtenSays } from "./tools";

const none = { web: false, files: false, ask_writes: true, commands: false, ask_commands: true, pictures: false, ask_new_tools: true, app: false, dice: false, folder: null };

test("files and commands are this computer's account's, need a folder, and ask while they are on", () => {
  const labels = (lines: { label: string }[]) => lines.map(({ label }) => label);
  expect(labels(toolLines(none, false, true))).toEqual(["Web", "Image generation", "Cardwave", "Dice"]);
  const bare = toolLines(none, true, false);
  expect(bare.map(({ label, says, off }) => [label, says, off])).toEqual([
    ["Web", "Search and read web pages", false],
    ["Files", "Choose a folder first", true],
    ["Commands", "Choose a folder first", true],
    ["Image generation", "Set up the image model first", true],
    ["Cardwave", "Use and change your characters, chats and settings; each change asked first", false],
    ["Dice", "Lets the AI roll dice; Cardwave rolls them, so the result is fair.", false],
  ]);
  const on = toolLines({ ...none, files: true, commands: true, folder: "D:\Shared" }, true, true);
  expect(on.map(({ label, says, off }) => [label, says, off])).toEqual([
    ["Web", "Search and read web pages", false],
    ["Files", "D:\Shared only", false],
    ["Ask before writing", "Each file is shown to you before it is written", false],
    ["Commands", "Run in D:\Shared, shut off from the rest of the computer and the internet", false],
    ["Ask before running", "Each command is shown to you before it runs", false],
    ["Image generation", "Uses the image model", false],
    ["Cardwave", "Use and change your characters, chats and settings; each change asked first", false],
    ["Dice", "Lets the AI roll dice; Cardwave rolls them, so the result is fair.", false],
  ]);
});

test("the link to the tools the model wrote says how many there are and whether a new one asks", () => {
  expect(writtenSays(0, true)).toBe("None yet · ask before a new one runs");
  expect(writtenSays(1, true)).toBe("1 tool · ask before a new one runs");
  expect(writtenSays(3, false)).toBe("3 tools · a new one runs without asking");
});
