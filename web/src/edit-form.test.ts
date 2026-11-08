import { describe, expect, it } from "vitest";
import { count, field } from "./edit-form";

describe("count", () => {
  it("shows a wrong number with the app's own red line, its range, and not the browser's message (A17)", () => {
    const told: number[] = [];
    const input = count(5, (value) => told.push(value), { least: 0, most: 100 });
    const node = field("Probability (%)", input, [], "The chance that the entry is used.");
    const hint = node.querySelector("p.hint")!;
    input.value = "150";
    input.dispatchEvent(new Event("input"));
    input.dispatchEvent(new Event("change"));
    expect([input.classList.contains("wrong"), input.ariaInvalid, hint.textContent, told]).toEqual([true, "true", "From 0 to 100", []]);
    // The browser's own message is held back: the field says it.
    const asked = new Event("invalid", { cancelable: true });
    input.dispatchEvent(asked);
    expect(asked.defaultPrevented).toBe(true);
    input.value = "50";
    input.dispatchEvent(new Event("input"));
    expect([input.classList.contains("wrong"), hint.textContent, told]).toEqual([false, "The chance that the entry is used.", [50]]);
  });
});
