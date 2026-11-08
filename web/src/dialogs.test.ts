// What dialogs.ts decides, without a browser: `step`, `within`, and of `menuOn` a menu's groups, its choices and
// its lines that cannot be picked.
import { afterEach, describe, expect, test, vi } from "vitest";
import { menuOn, step, within, type MenuItem } from "./dialogs";
import { el } from "./dom";

afterEach(() => document.body.replaceChildren());

describe("step", () => {
  const buttons = () => {
    const all = ["one", "two", "three"].map((name) => el("button", null, name));
    document.body.append(...all);
    return all;
  };
  const focused = () => document.activeElement?.textContent;

  test("down goes to the next and after the last to the first, up to the one before and before the first to the last", () => {
    const all = buttons();
    all[0].focus();
    step(all, true);
    expect(focused()).toBe("two");
    step(all, true);
    step(all, true);
    expect(focused()).toBe("one");
    step(all, false);
    expect(focused()).toBe("three");
    step(all, false);
    expect(focused()).toBe("two");
  });

  test("from outside them, down goes to the first and up to the last", () => {
    const all = buttons();
    step(all, true);
    expect(focused()).toBe("one");
    all[0].blur();
    step(all, false);
    expect(focused()).toBe("three");
  });
});

describe("within", () => {
  test("a thing that has room begins where it would", () => {
    expect(within(100, 50, 500)).toBe(100);
  });

  test("one that would reach past the window's end is moved back, to 4 px from the edge", () => {
    expect(within(480, 50, 500)).toBe(446);
    expect(within(446, 50, 500)).toBe(446);
  });

  test("it never begins nearer than 4 px to the window's start, also when it is larger than the window", () => {
    expect(within(0, 50, 500)).toBe(4);
    expect(within(-30, 50, 500)).toBe(4);
    expect(within(100, 600, 500)).toBe(4);
  });
});

describe("menuOn", () => {
  /** A button with a menu of `items` in the page, opened, and what the menu holds. */
  function opened(items: MenuItem[]) {
    const button = el("button", { type: "button" }, "Open");
    const node = menuOn(button, items);
    document.body.append(node);
    button.click();
    const list = node.querySelector<HTMLElement>(".pop")!;
    return {
      button,
      list,
      lines: [...list.querySelectorAll<HTMLButtonElement>("button")],
      key: (key: string) => node.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true })),
    };
  }

  test("a group's name stands over the line that begins it, under a rule unless the menu begins with it", () => {
    const none = () => {};
    const { list } = opened([
      { label: "One", group: "First", action: none },
      { label: "Two", action: none },
      { label: "Three", group: "Second", action: none },
    ]);
    expect([...list.children].map((child) => (child.tagName === "BUTTON" ? child.textContent : child.tagName === "HR" ? "rule" : `group ${child.textContent}`))).toEqual([
      "group First",
      "One",
      "Two",
      "rule",
      "group Second",
      "Three",
    ]);
    expect(list.querySelector(".menu-group")!.role).toBe("presentation");
  });

  test("a line's grey line under it describes it and is not part of its name", () => {
    const { lines } = opened([{ label: "Add a lorebook", sub: "Facts the AI looks up", action: () => {} }]);
    expect(lines[0].ariaLabel).toBe("Add a lorebook");
    expect(lines[0].getAttribute("aria-description")).toBe("Facts the AI looks up");
  });

  test("a line that is one choice of several says so and whether it is the one made, which has the tick; any other line is a plain one with its own drawing", () => {
    const none = () => {};
    const { lines } = opened([
      { label: "Chosen", chosen: true, action: none },
      { label: "Not chosen", chosen: false, shape: "edit", action: none },
      { label: "Plain", shape: "copy", action: none },
    ]);
    expect(lines.map((line) => [line.role, line.ariaChecked ?? null])).toEqual([
      ["menuitemradio", "true"],
      ["menuitemradio", "false"],
      ["menuitem", null],
    ]);
    // The tick is the chosen line's alone: one that is not chosen keeps the drawing it was given.
    const drawn = (line: HTMLElement) => line.querySelector("svg")?.innerHTML ?? null;
    expect(drawn(lines[0])).not.toBeNull();
    expect(drawn(lines[1])).not.toBe(drawn(lines[0]));
    expect(drawn(lines[2])).not.toBe(drawn(lines[0]));
  });

  test("a line that cannot be picked says so, does nothing when pressed and leaves the menu open, and the arrows pass it by", () => {
    const [first, off, last] = [vi.fn(), vi.fn(), vi.fn()];
    const { list, lines, key } = opened([
      { label: "First", action: first },
      { label: "Off", off: true, action: off },
      { label: "Last", action: last },
    ]);
    expect(lines.map((line) => line.ariaDisabled ?? null)).toEqual([null, "true", null]);
    // It is no disabled button: a press on one would take the focus out of the menu.
    expect(lines[1].disabled).toBe(false);
    expect(document.activeElement).toBe(lines[0]);
    key("ArrowDown");
    expect(document.activeElement).toBe(lines[2]);
    key("ArrowDown");
    expect(document.activeElement).toBe(lines[0]);
    key("ArrowUp");
    expect(document.activeElement).toBe(lines[2]);
    lines[1].click();
    expect(off).not.toHaveBeenCalled();
    expect(list.hidden).toBe(false);
    lines[2].click();
    expect(last).toHaveBeenCalledTimes(1);
    expect(list.hidden).toBe(true);
  });

  test("whether a line can be picked is read anew each time the menu opens", () => {
    const later: MenuItem = { label: "Later", action: () => {} };
    const { button, lines } = opened([{ label: "First", action: () => {} }, later]);
    expect(lines[1].ariaDisabled ?? null).toBeNull();
    button.click();
    later.off = true;
    button.click();
    expect(lines[1].ariaDisabled).toBe("true");
    button.click();
    later.off = false;
    button.click();
    expect(lines[1].ariaDisabled ?? null).toBeNull();
  });

  test("a menu that begins with a line that cannot be picked opens with the focus on the first that can", () => {
    const none = () => {};
    const { lines } = opened([
      { label: "Off", off: true, action: none },
      { label: "On", action: none },
    ]);
    expect(document.activeElement).toBe(lines[1]);
  });
});
