// Tested here: a text kept unsaved that comes back into the field is told as typed (`InPlace.input`); a field showing a button to begin is a button (`InPlace.button`).
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

test("a field that shows a button to begin (Add tags) is a button to who cannot see it, and is none once it shows its text", () => {
  const node = el("div");
  let empty = true;
  const begin = inPlace(node, { label: "Tags", value: () => "", show: () => [empty ? "Add tags" : "one, two"], button: () => empty, commit: () => undefined });
  expect(node.getAttribute("role")).toBe("button");
  begin();
  empty = false;
  node.querySelector("input")?.dispatchEvent(new FocusEvent("blur"));
  expect(node.getAttribute("role")).toBeNull();
});
