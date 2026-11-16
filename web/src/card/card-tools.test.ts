// What card-tools.ts decides alone: a Keep all whose save fails leaves the changes waiting.
import { expect, test, vi } from "vitest";
import { useLanguage } from "../language/language";
import type { Card } from "./card-page";
import { wholeCard } from "./card-tools";

vi.mock("../api/client", () => ({ rewrite: vi.fn(async () => ({ text: "changed" })) }));
vi.mock("./card-page", async (original) => ({ ...(await original<typeof import("./card-page")>()), save: vi.fn(async () => false) }));

test("Keep all whose save fails puts the changes back to wait", async () => {
  useLanguage("en");
  const part = (text: string) => [{ text }];
  const c = { language: null, edit: { characters: [{ greetings: part("hello"), group_greetings: [], depth_prompts: [], description: [], personality: [], scenario: [], example_dialogue: [], system_prompt: [], post_history: [], creator_notes: "" }] }, translating: null, page: {}, notice: document.createElement("div") } as unknown as Card;
  const tools = wholeCard(c);
  const menu = tools.button();
  for (const item of menu.querySelectorAll<HTMLButtonElement>("[role=menuitem]")) {
    item.click();
    if (!tools.bar.querySelector("input")) break;
  }
  await vi.waitFor(() => expect(tools.bar.querySelector(".btn-primary")).not.toBeNull());
  const keep = tools.bar.querySelector<HTMLButtonElement>(".btn-primary")!;
  keep.click();
  await new Promise((done) => setTimeout(done, 0));
  expect(tools.bar.hidden).toBe(false);
  expect(tools.bar.querySelector(".btn-primary")).not.toBeNull();
});
