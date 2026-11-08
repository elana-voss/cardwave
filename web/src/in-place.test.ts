// Tested here: a text kept unsaved that comes back into the field is told as typed (`InPlace.input`).
import { expect, test, vi } from "vitest";
import { el } from "./dom";
import { inPlace } from "./in-place";

vi.mock("./unsaved", () => ({ keep: vi.fn(), forget: vi.fn(), kept: vi.fn(async () => "Hello there") }));

test("a text that comes back unsaved is told as typed, so what waits on typing (New chat) is ready", async () => {
  const node = el("div");
  document.body.append(node);
  const input = vi.fn();
  const begin = inPlace(node, { label: "First message", value: () => "", show: () => [], commit: () => undefined, multiline: true, input, keep: () => "card.1.en.greeting" });
  begin();
  await vi.waitFor(() => expect(input).toHaveBeenCalledWith("Hello there"));
});
