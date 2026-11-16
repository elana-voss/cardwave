// What lore-tools.ts decides alone: a Keep that cannot be saved leaves the AI's change, and the bar of a running tool is left alone.
import { expect, test, vi } from "vitest";
import { rewriteLore } from "../api/client";
import { useLanguage } from "../language/language";
import type { Book } from "./lorebook-entry";
import { saveEntry } from "./lorebook-entry";
import { drawBar, loreTools, proposalBox } from "./lore-tools";

vi.mock("../api/client", () => ({ rewriteLore: vi.fn() }));
vi.mock("./lorebook-entry", () => ({ saveEntry: vi.fn() }));

const entry = { reference: "a", content: "teh cat", keywords: ["cat"], secondary: [], trigger: "keywords" };
const text = { reference: "a", text: "the cat", keywords: ["cat"], secondary_keywords: [] };
const book = () => {
  const b = { book: { entries: [entry] }, proposed: new Map(), bar: document.createElement("div"), notice: document.createElement("div"), leaving: new AbortController(), redraw: vi.fn(), attempt: (step: () => Promise<void>) => step().catch(() => undefined) };
  return b as unknown as Book;
};

test("a Keep whose save fails leaves the change waiting", async () => {
  useLanguage("en");
  vi.mocked(saveEntry).mockRejectedValueOnce(new Error("offline"));
  const b = book();
  b.proposed.set("a", { said: "x", made: "fix", text });
  proposalBox(b, entry as never)!.querySelector<HTMLButtonElement>(".btn-primary")!.click();
  await new Promise((done) => setTimeout(done, 0));
  expect(b.proposed.has("a")).toBe(true);
});

test("a Keep or Undo while another tool runs leaves its working line", async () => {
  useLanguage("en");
  vi.mocked(rewriteLore).mockReturnValue(new Promise(() => undefined));
  const b = book();
  b.proposed.set("a", { said: "x", made: "fix", text });
  loreTools(b).querySelectorAll<HTMLButtonElement>("[role=menuitem]")[1].click();
  const working = b.bar.textContent;
  expect(working).toContain("Stop");
  drawBar(b);
  expect(b.bar.textContent).toBe(working);
});
