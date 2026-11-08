// What create.ts decides: where each line of "Create" leads, and what it has the screen there do.
//
// The window "New chat", the start of a chat and the window "New lorebook" are stood in for (`vi.mock`).
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { newChatDialog } from "../library/add-character";
import { createMenu, freshStart } from "./create";
import { el, type View } from "../dom";
import { beginChat } from "../library/library-actions";
import { newLorebook } from "../lorebook/lorebook-dialog";

// The window "New chat" and the start of a chat are their own modules': here only what "Create" asks of them.
vi.mock("../library/add-character", () => ({ newChatDialog: vi.fn() }));
vi.mock("../library/library-actions", () => ({ beginChat: vi.fn() }));
vi.mock("../lorebook/lorebook-dialog", () => ({ newLorebook: vi.fn() }));

beforeEach(() => document.body.append(el("main", { id: "view" }), el("div", { id: "toast" })));
afterEach(() => {
  document.body.replaceChildren();
  vi.clearAllMocks();
});

/** The menu on a button, and its line called `name`. */
function create(open: (address: string) => View | null) {
  const node = createMenu(el("button", { type: "button" }, "Create"), open);
  document.body.append(node);
  const line = (name: string) => [...node.querySelectorAll<HTMLElement>('[role="menuitem"]')].find((one) => one.textContent === name)!;
  return { node, line };
}

test("Create has a line for a new chat and for each thing that is imported or made, and places itself", () => {
  const { node } = create(() => null);
  expect([...node.querySelectorAll('[role="menuitem"]')].map((line) => line.textContent)).toEqual(["New chat", "Chat without a character", "New character", "New persona", "New lorebook", "Import card", "Import lorebook"]);
  // What is brought in stands under a rule.
  expect(node.querySelector("hr + [role=menuitem]")?.textContent).toBe("Import card");
  expect(node.classList.contains("float")).toBe(true);
});

test("a line that imports or makes something shows its screen and has it begin at once", () => {
  const began: string[] = [];
  const opened: string[] = [];
  const { line } = create((address) => {
    opened.push(address);
    return { node: el("div"), create: () => void began.push(address) };
  });
  line("Import card").click();
  line("New persona").click();
  line("Import lorebook").click();
  expect(opened).toEqual(["#/library", "#/library/personas", "#/library/lorebooks"]);
  expect(began).toEqual(opened);
});

test("New card shows the form of a new card, which is a screen of its own", () => {
  const opened: string[] = [];
  const { line } = create((address) => {
    opened.push(address);
    return { node: el("div") };
  });
  line("New character").click();
  expect(opened).toEqual(["#/library/new"]);
});

test("a screen that could not be shown, or that has nothing to begin, is left at that", () => {
  const screens: (View | null)[] = [null, { node: el("div") }];
  const { line } = create(() => screens.shift()!);
  expect(() => line("Import card").click()).not.toThrow();
  expect(() => line("New persona").click()).not.toThrow();
  expect(screens).toEqual([]);
});

test("New lorebook opens its window over the screen that is shown, or the page's place without one", () => {
  const { line } = create(() => null);
  line("New lorebook").click();
  const screen = el("div");
  document.querySelector("#view")!.append(screen);
  line("New lorebook").click();
  expect(vi.mocked(newLorebook).mock.calls).toEqual([[document.querySelector("#view")], [screen]]);
});

test("New chat opens its window over the screen that is shown, and the characters picked start a chat, in their order, each with its card's newest version, as the persona picked", async () => {
  const screen = el("div");
  document.querySelector("#view")!.append(screen);
  const { line } = create(() => null);
  line("New chat").click();
  expect(newChatDialog).toHaveBeenCalledTimes(1);
  const [home, start] = vi.mocked(newChatDialog).mock.calls[0];
  expect(home).toBe(screen);

  vi.mocked(beginChat).mockResolvedValue();
  await start([
    { cardId: 7, character: "mira", versionId: 31, name: "Mira" },
    { cardId: 4, character: "bo", versionId: 12, name: "Bo" },
  ], 5);
  expect(beginChat).toHaveBeenCalledWith(
    [
      { version_id: 31, character: "mira" },
      { version_id: 12, character: "bo" },
    ],
    undefined,
    5,
  );
});

test("New chat's window, while the library has no character, offers New character and Import card, which lead to their screens", () => {
  const opened: string[] = [];
  const { line } = create((address) => {
    opened.push(address);
    return { node: el("div") };
  });
  line("New chat").click();
  const ways = vi.mocked(newChatDialog).mock.calls[0][2]!;
  expect(ways.map((way) => way.label)).toEqual(["New character", "Import card"]);
  for (const way of ways) way.go();
  expect(opened).toEqual(["#/library/new", "#/library"]);
});

test("without a screen the window opens over the page's place, and a chat that could not be started is the window's to say", async () => {
  const { line } = create(() => null);
  line("New chat").click();
  const [home, start] = vi.mocked(newChatDialog).mock.calls[0];
  expect(home).toBe(document.querySelector("#view"));

  vi.mocked(beginChat).mockRejectedValue(new Error("the card is in the Trash"));
  await expect(start([{ cardId: 7, character: "mira", versionId: 31, name: "Mira" }], null)).rejects.toThrow("the card is in the Trash");
});

test("Chat without a character starts a chat with nobody, and a chat that could not be started says why", async () => {
  const { line } = create(() => null);
  vi.mocked(beginChat).mockResolvedValue();
  line("Chat without a character").click();
  expect(beginChat).toHaveBeenCalledWith([]);

  vi.mocked(beginChat).mockRejectedValue(new Error("the server is not reached"));
  line("Chat without a character").click();
  await vi.waitFor(() => expect(document.querySelector("#toast")!.textContent).toContain("The server is not reached"));
});

test("the fresh start has Create's five new things and its two imports", () => {
  const node = freshStart(() => null);
  const [made, brought] = [...node.querySelectorAll(".lst")].map((group) => [...group.querySelectorAll("button")].map((line) => line.textContent));
  expect(made).toEqual(["New chat", "Chat without a character", "New character", "New persona", "New lorebook"]);
  expect(brought).toEqual(["Import card", "Import lorebook"]);
});
