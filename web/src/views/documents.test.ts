import { expect, test, vi } from "vitest";
import { listCards, listChats, listDocuments } from "../api/client";
import { useLanguage } from "../language/language";
import { documentsView, shownName } from "./documents";

vi.mock("../api/client", () => ({ listCards: vi.fn(async () => []), listChats: vi.fn(async () => []), listDocuments: vi.fn(async () => []), getSearchModel: vi.fn(async () => ({ state: "ready" })) }));

test("a document's row names it without its file's ending", () => {
  expect(["Castle history.md", "Council minutes.txt", "notes.v2.docx", "README", "Plan. Draft"].map(shownName)).toEqual(["Castle history", "Council minutes", "notes.v2", "README", "Plan. Draft"]);
});

test("adding a document with no chat and no character says one is needed, with no dialog", async () => {
  useLanguage("en");
  vi.mocked(listChats).mockResolvedValue([]);
  vi.mocked(listCards).mockResolvedValue([]);
  vi.mocked(listDocuments).mockResolvedValue([]);
  const view = documentsView();
  document.body.replaceChildren(view.node);
  const add = [...view.node.querySelectorAll("button")].find((b) => b.textContent === "Add a document")!;
  add.click();
  const field = view.node.querySelector<HTMLInputElement>("input[type=file]")!;
  Object.defineProperty(field, "files", { value: [new File(["a"], "a.txt")] });
  field.dispatchEvent(new Event("change"));
  await vi.waitFor(() => expect(view.node.textContent).toContain("belongs to a character or a chat"));
  expect(document.querySelector("dialog")).toBeNull();
});

test("chats of one name are told apart by their day in \"Used for\" and in a document's line, as the rail does", async () => {
  useLanguage("en");
  const at = (day: number, hour: number) => new Date(2026, 9, day, hour).getTime();
  const chat = (id: number, updated_at: number) => ({ id, title: "", names: ["Mira"], updated_at }) as never;
  vi.mocked(listChats).mockResolvedValue([chat(1, at(3, 9)), chat(2, at(2, 9))]);
  vi.mocked(listCards).mockResolvedValue([]);
  vi.mocked(listDocuments).mockResolvedValue([{ id: 5, name: "a.txt", words: 3, chat_id: 1, card_id: null, owner_name: "", created_at: 0 }] as never);
  const view = documentsView();
  document.body.replaceChildren(view.node);
  await vi.waitFor(() => expect(view.node.querySelector(".document-row")).not.toBeNull());
  const line = view.node.querySelector(".document-row a")!.textContent!;
  expect(line).toMatch(/^Mira · .+/);
  expect(line).not.toBe("Mira");
});

