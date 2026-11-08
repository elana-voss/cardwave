// What add-character.ts's window offers while the library is empty.
//
// The server's list of cards is stood in for (`vi.mock`).
import { afterEach, expect, test, vi } from "vitest";
import { newChatDialog } from "./add-character";
import { el } from "../dom";

vi.mock("../api/client", () => ({ listCards: vi.fn(async () => []), getCard: vi.fn(), listPersonas: vi.fn(async () => []) }));

afterEach(() => document.body.replaceChildren());

test("New chat, while the library has no character, says so with the ways to one, each closing the window", async () => {
  const home = el("div");
  document.body.append(home);
  const went: string[] = [];
  newChatDialog(home, async () => {}, [
    { label: "New character", go: () => went.push("new") },
    { label: "Import card", go: () => went.push("import") },
  ]);
  const box = document.querySelector("dialog")!;
  await vi.waitFor(() => expect(box.querySelector(".empty")?.textContent).toContain("The library has no characters yet."));
  const buttons = [...box.querySelectorAll<HTMLButtonElement>(".empty button")];
  expect(buttons.map((button) => button.textContent)).toEqual(["New character", "Import card"]);
  buttons[1].click();
  expect(went).toEqual(["import"]);
  expect(box.open).toBe(false);
});
