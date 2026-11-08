import { describe, expect, it } from "vitest";
import { closedPrivate, opened, privateBox, privateSent, type PrivateState } from "./private-list";

const TOPICS = ["romance", "violence", "swearing-crude-talk", "grief-and-loss", "drugs-drinking"];
const text = (topic: string) => ({ id: `pick-${topic}`, said: [] });
const TEXTS = TOPICS.map(text);

const box = (state: PrivateState) => document.body.appendChild(privateBox({ state, changed: () => {} })); // In the page, or a tick fires no change.
const row = (node: HTMLElement, topic: string) => node.querySelectorAll(".seg")[TOPICS.indexOf(topic)].parentElement!;
const press = (node: HTMLElement, topic: string, words: string) =>
  [...row(node, topic).querySelectorAll<HTMLButtonElement>("button")].find((one) => one.textContent === words)!.click();
const never = (node: HTMLElement, topic: string) => row(node, topic).querySelector<HTMLInputElement>("input[type=checkbox]");

describe("the private list", () => {
  it("sends nothing while closed", () => {
    expect(privateSent(closedPrivate(TEXTS))).toEqual({ open: false, rows: [], free: "" });
  });

  it("leaves the rows of don't know out of what it sends, and trims the free line", () => {
    const state = opened(closedPrivate(TEXTS));
    const node = box(state);
    expect(row(node, "grief-and-loss").previousElementSibling?.textContent).toBe("Grief and loss");
    press(node, "romance", "Yes");
    press(node, "violence", "No");
    never(node, "violence")!.click();
    state.free = "  no spiders ";
    expect(privateSent(state)).toEqual({
      open: true,
      rows: [
        { topic: text("romance"), answer: "yes", never: false },
        { topic: text("violence"), answer: "no", never: true },
      ],
      free: "no spiders",
    });
  });

  it("has Never only beside a No, and leaving the No clears it", () => {
    const state = opened(closedPrivate(TEXTS));
    const node = box(state);
    expect(never(node, "romance")).toBeNull();
    press(node, "romance", "No");
    never(node, "romance")!.click();
    press(node, "romance", "Maybe");
    expect(never(node, "romance")).toBeNull();
    press(node, "romance", "No");
    expect(never(node, "romance")!.checked).toBe(false);
  });

  it("takes three Nevers at most: the other ticks are off until one is taken back", () => {
    const state = opened(closedPrivate(TEXTS));
    const node = box(state);
    for (const topic of TOPICS) press(node, topic, "No");
    for (const topic of TOPICS.slice(0, 3)) never(node, topic)!.click();
    expect(never(node, "drugs-drinking")!.disabled).toBe(true);
    expect(never(node, "romance")!.disabled).toBe(false);
    never(node, "romance")!.click();
    expect(never(node, "drugs-drinking")!.disabled).toBe(false);
  });
});
