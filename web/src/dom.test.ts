// What dom.ts decides, without a browser: the rules of its helpers that are logic. What a screen
// does with them, and how it looks, is the browser tests' (e2e/tests).
//
// Tested here: `announce` fading, `copyText` without a clipboard, `told` and `reason`, `oneAtATime`, `latest`, `suggest`,
// `selectField`, `savedChoice` and `atMost`.
import { afterEach, describe, expect, test, vi } from "vitest";
import { announce, atMost, clearNotice, copyText, el, latest, oneAtATime, reason, savedChoice, selectField, suggest, toast, told } from "./dom";

afterEach(() => document.body.replaceChildren());

describe("announce", () => {
  test("a notice without a button goes away on its own after a few seconds, carried over one change of screen or not; one with Undo stays", () => {
    vi.useFakeTimers();
    document.body.append(el("div", { id: "toast" }));
    announce("The chat model is set up.", undefined, true);
    expect(toast().textContent).toBe("The chat model is set up.");
    // `carry` lets it outlive the one change of screen that follows.
    clearNotice();
    expect(toast().textContent).toBe("The chat model is set up.");
    // But it still fades on its own a few seconds later, where no further change of screen clears it.
    vi.advanceTimersByTime(6000);
    expect(toast().textContent).toBe("");
    // One with Undo stays, so it can still be taken back.
    announce("Entry deleted.", async () => {});
    vi.advanceTimersByTime(60000);
    expect(toast().textContent).toBe("Entry deleted.Undo");
    vi.useRealTimers();
  });

  test("a notice that stays comes back after a later notice goes, and leaves for good at its button", async () => {
    vi.useFakeTimers();
    document.body.replaceChildren(el("div", { id: "toast" }));
    let pressed = 0;
    announce("The voice did not download.", async () => void pressed++, "stays", "Try again");
    announce("Saved.");
    expect(toast().textContent).toBe("Saved.");
    vi.advanceTimersByTime(6000);
    expect(toast().textContent).toBe("The voice did not download.Try again");
    // One with Undo goes at the change of screen, and the one that stays is back.
    announce("Entry deleted.", async () => {});
    clearNotice();
    expect(toast().textContent).toBe("The voice did not download.Try again");
    // A later notice's Undo, pressed, brings it back at once.
    announce("Entry deleted.", async () => {});
    toast().querySelector("button")!.click();
    await Promise.resolve();
    expect(toast().textContent).toBe("The voice did not download.Try again");
    toast().querySelector("button")!.click();
    await Promise.resolve();
    expect(pressed).toBe(1);
    announce("Saved.");
    vi.advanceTimersByTime(6000);
    expect(toast().textContent).toBe("");
    vi.useRealTimers();
  });
});

/** A promise, and what settles it from outside. */
function held<T>(): { promise: Promise<T>; answer(value: T): void; fail(error: unknown): void } {
  let answer!: (value: T) => void;
  let fail!: (error: unknown) => void;
  const promise = new Promise<T>((resolve, reject) => ([answer, fail] = [resolve, reject]));
  return { promise, answer, fail };
}

describe("told and reason", () => {
  test("what went wrong is told in the words it came with, an error's message or the thing itself", () => {
    expect(told(new Error("the tags are away"))).toBe("the tags are away");
    expect(told("no such card")).toBe("no such card");
    expect(told(404)).toBe("404");
  });

  test("the reason is those words as a sentence: its first letter in upper case, the rest as it is", () => {
    expect(reason(new Error("the tags are away"))).toBe("The tags are away");
    expect(reason(new Error("HTTP 500 from the Server"))).toBe("HTTP 500 from the Server");
    expect(reason(new Error(""))).toBe("");
  });
});

describe("oneAtATime", () => {
  test("an action that is done answers true, and one asked for while another runs is not started", async () => {
    const attempt = oneAtATime(el("div"));
    const first = held<void>();
    const ran: string[] = [];
    const running = attempt(async () => {
      ran.push("first");
      await first.promise;
    });
    expect(await attempt(async () => void ran.push("second"))).toBe(false);
    first.answer();
    expect(await running).toBe(true);
    expect(ran).toEqual(["first"]);
    // Once it is through, the next one runs.
    expect(await attempt(async () => void ran.push("third"))).toBe(true);
    expect(ran).toEqual(["first", "third"]);
  });

  test("an action that fails answers false and says why in the notice, behind its name if it has one", async () => {
    const notice = el("div");
    const attempt = oneAtATime(notice);
    const failing = async () => {
      throw new Error("the server is away");
    };
    expect(await attempt(failing)).toBe(false);
    expect(notice.querySelector('[role="alert"]')?.textContent).toBe("The server is away");
    expect(await attempt(failing, "Tern Rock")).toBe(false);
    expect(notice.textContent).toBe("Tern Rock: The server is away");
  });

  test("the reason stands until the next action starts, and a failure holds up none", async () => {
    const notice = el("div");
    const attempt = oneAtATime(notice);
    await attempt(async () => {
      throw new Error("the server is away");
    });
    const next = held<void>();
    const running = attempt(() => next.promise);
    expect(notice.querySelector('[role="alert"]')).toBeNull();
    next.answer();
    expect(await running).toBe(true);
  });
});

describe("latest", () => {
  test("the answer is shown, and one that comes late never replaces a newer one", async () => {
    const [first, second] = [held<string>(), held<string>()];
    const asked = [first, second];
    const shown: string[] = [];
    const read = latest(el("div"), () => asked.shift()!.promise, (answer: string) => void shown.push(answer));
    const [early, late] = [read(), read()];
    second.answer("newer");
    await late;
    expect(shown).toEqual(["newer"]);
    first.answer("older");
    await early;
    expect(shown).toEqual(["newer"]);
  });

  test("why a list could not be read stands in the notice until one is read, and a late failure says nothing", async () => {
    const notice = el("div");
    const asked = [held<string>(), held<string>(), held<string>()];
    const [failing, older, newer] = asked;
    const shown: string[] = [];
    const read = latest(notice, () => asked.shift()!.promise, (answer: string) => void shown.push(answer));
    const failed = read();
    failing.fail(new Error("the list is away"));
    await failed;
    expect(notice.querySelector('[role="alert"]')?.textContent).toBe("The list is away");
    expect(shown).toEqual([]);

    // The next reading is overtaken by one after it; its failure comes late and is dropped.
    const [early, late] = [read(), read()];
    newer.answer("read");
    await late;
    expect(shown).toEqual(["read"]);
    expect(notice.querySelector('[role="alert"]')).toBeNull();
    older.fail(new Error("too late to matter"));
    await early;
    expect(notice.querySelector('[role="alert"]')).toBeNull();
  });
});

describe("suggest", () => {
  const MODELS = ["anchor-1", "reef-1", "tide-1", "tide-2"];
  /** A field that offers the models that have what was typed. `asked` notes what it was asked with. */
  function field(models = MODELS, inside = false, chosen?: string) {
    const input = el("input", { name: "model" });
    const asked: string[] = [];
    const { node, list, open } = suggest(
      input,
      (typed) => {
        asked.push(typed);
        return models.filter((model) => model.includes(typed));
      },
      inside,
      chosen,
    );
    document.body.append(node, list);
    const lines = () => [...list.children].map((line) => line.textContent);
    const marked = () => list.querySelector('[aria-selected="true"]')?.textContent ?? null;
    const type = (text: string) => {
      input.value = text;
      input.dispatchEvent(new Event("input"));
    };
    /** Presses a key in the field, and answers whether the field kept it for itself. */
    const press = (key: string) => {
      const event = new KeyboardEvent("keydown", { key, cancelable: true, bubbles: true });
      input.dispatchEvent(event);
      return event.defaultPrevented;
    };
    return { input, list, open, asked, lines, marked, type, press };
  }

  test("the list is shut until the field is typed in, and then offers what is said for what was typed", () => {
    const { input, list, lines, type } = field();
    expect(list.hidden).toBe(true);
    expect(input.ariaExpanded).toBe("false");
    expect(input.getAttribute("aria-controls")).toBe(list.id);
    type("tide");
    expect(list.hidden).toBe(false);
    expect(input.ariaExpanded).toBe("true");
    expect(lines()).toEqual(["tide-1", "tide-2"]);
  });

  test("a value that was not typed there narrows nothing: one the page put into the field, and a line taken", () => {
    const { input, open, asked, lines, type, press } = field();
    input.value = "reef-1";
    open();
    expect(asked).toEqual([""]);
    expect(lines()).toEqual(MODELS);

    // Typed, it narrows; the line taken with the arrows and Enter then stands in the field and narrows nothing.
    type("tide");
    press("ArrowDown");
    press("Enter");
    expect(input.value).toBe("tide-1");
    open();
    expect(asked.at(-1)).toBe("");
    expect(lines()).toEqual(MODELS);
    // Also when its whole name was typed before it was taken.
    type("tide-2");
    press("ArrowDown");
    press("Enter");
    open();
    expect(lines()).toEqual(MODELS);
  });

  test("the arrows open the list, go through its lines and around, and say which line they are at", () => {
    const { input, list, marked, press } = field(["one", "two", "three"]);
    expect(press("ArrowDown")).toBe(true);
    expect(list.hidden).toBe(false);
    expect(marked()).toBeNull();
    press("ArrowDown");
    expect(marked()).toBe("one");
    expect(input.getAttribute("aria-activedescendant")).toBe(list.children[0].id);
    press("ArrowDown");
    press("ArrowDown");
    expect(marked()).toBe("three");
    press("ArrowDown");
    expect(marked()).toBe("one");
    press("ArrowUp");
    expect(marked()).toBe("three");
    expect(list.querySelectorAll('[aria-selected="true"]')).toHaveLength(1);
  });

  test("from no line, the arrow up goes to the last", () => {
    const { marked, open, press } = field(["one", "two", "three"]);
    open();
    press("ArrowUp");
    expect(marked()).toBe("three");
  });

  test("Enter takes the line the arrows marked and is the field's then; with no line marked it is the form's", () => {
    const { input, list, type, press } = field();
    type("ti");
    expect(press("Enter")).toBe(false);
    expect(input.value).toBe("ti");
    press("ArrowDown");
    press("ArrowDown");
    expect(press("Enter")).toBe(true);
    expect(input.value).toBe("tide-2");
    expect(list.hidden).toBe(true);
    expect(input.getAttribute("aria-activedescendant")).toBeNull();
  });

  test("a press takes the line pressed, and leaves the focus in the field", () => {
    const { input, list, open } = field();
    open();
    const line = list.children[1] as HTMLElement;
    const down = new MouseEvent("mousedown", { bubbles: true, cancelable: true });
    line.dispatchEvent(down);
    expect(down.defaultPrevented).toBe(true);
    line.click();
    expect(input.value).toBe("reef-1");
    expect(list.hidden).toBe(true);
  });

  test("Escape shuts the open list and is the field's then; with the list shut it is not", () => {
    const { list, open, press } = field();
    open();
    expect(press("Escape")).toBe(true);
    expect(list.hidden).toBe(true);
    expect(press("Escape")).toBe(false);
  });

  test("the list shuts when the focus leaves the field", () => {
    const { input, list, open } = field();
    open();
    input.dispatchEvent(new FocusEvent("blur"));
    expect(list.hidden).toBe(true);
  });

  test("with nothing to offer the list stays shut, and the arrows are the field's own", () => {
    const { input, list, open, type, press } = field();
    type("zz");
    expect(list.hidden).toBe(true);
    expect(input.ariaExpanded).toBe("false");
    expect(press("ArrowDown")).toBe(false);
    expect(press("ArrowUp")).toBe(false);
    open();
    expect(list.hidden).toBe(true);
  });

  test("a list inside the window is open from the start, stays open as the focus leaves and on Escape, which is the window's, and after a line taken", () => {
    const { input, list, lines, press, type } = field(MODELS, true);
    expect(list.hidden).toBe(false);
    expect(lines()).toEqual(MODELS);
    input.dispatchEvent(new FocusEvent("blur"));
    expect(list.hidden).toBe(false);
    expect(press("Escape")).toBe(false);
    expect(list.hidden).toBe(false);
    type("reef");
    (list.firstElementChild as HTMLElement).click();
    expect(input.value).toBe("reef-1");
    expect(lines()).toEqual(MODELS);
  });

  test("the value in use is ticked and marked in the list, until the arrows mark another; taking it gives its value alone", () => {
    const { input, list, open, marked, press } = field(MODELS, true, "reef-1");
    open();
    const chosen = list.querySelector<HTMLElement>('[aria-selected="true"]');
    expect(marked()).toBe("reef-1");
    expect(chosen?.querySelector("svg")).not.toBeNull();
    press("ArrowDown");
    expect(marked()).toBe("tide-1");
    expect(chosen?.querySelector("svg")).not.toBeNull();
    press("ArrowUp");
    press("Enter");
    expect(input.value).toBe("reef-1");
  });
});

describe("selectField", () => {
  const CHOICES = [
    { value: "a", label: "Ada", group: "People" },
    { value: "b", label: "Bo" },
    { value: "c", label: "Cy", off: true },
  ];
  /** The field's menu lines, by their words. */
  const lines = (node: HTMLElement) => [...node.querySelectorAll<HTMLButtonElement>('[role="menuitemradio"]')];

  test("the field shows the choice made, its menu ticks it, and a line picked becomes the value and is told", () => {
    const took: string[] = [];
    const select = selectField(CHOICES, "a", (value) => took.push(value), { id: "who" });
    document.body.append(select.node);
    expect(select.field.id).toBe("who");
    expect(select.field.textContent).toBe("Ada");
    expect(lines(select.node).map((line) => [line.textContent, line.ariaChecked])).toEqual([["Ada", "true"], ["Bo", "false"], ["Cy", "false"]]);
    expect(select.node.querySelector(".menu-group")?.textContent).toBe("People");
    lines(select.node)[1].click();
    expect([select.value, took, select.field.textContent]).toEqual(["b", ["b"], "Bo"]);
    // A line that cannot be picked changes nothing.
    lines(select.node)[2].click();
    expect([select.value, took]).toEqual(["b", ["b"]]);
  });

  test("without a choice made it shows its placeholder, and other choices offered are its menu then", () => {
    const select = selectField([], "", () => {}, { placeholder: "Choose a provider" });
    document.body.append(select.node);
    expect(select.field.textContent).toBe("Choose a provider");
    select.offer(CHOICES);
    expect(lines(select.node)).toHaveLength(3);
    select.value = "b";
    expect(select.field.textContent).toBe("Bo");
  });

  test("a line picked leaves the focus on the field", () => {
    const select = selectField(CHOICES, "a", () => {});
    document.body.append(select.node);
    select.field.click();
    lines(select.node)[1].click();
    expect(select.value).toBe("b");
    expect(document.activeElement).toBe(select.field);
  });
});

describe("copyText", () => {
  test("a page that may not write to the clipboard, which has none outside https, says so", async () => {
    vi.stubGlobal("navigator", { clipboard: undefined });
    await expect(copyText("x")).rejects.toThrow("copying was not allowed here; select the text and press Ctrl+C");
    vi.unstubAllGlobals();
  });
});

describe("atMost", () => {
  const typed = (input: HTMLInputElement, value: string, caret: number) => {
    input.value = value;
    input.setSelectionRange(caret, caret);
    input.dispatchEvent(new Event("input"));
  };

  test("what is typed into a full field is refused where it is typed, the text after it kept; a paste keeps what fits; a 🌊 counts once", () => {
    const input = el("input");
    atMost(input, 5);
    typed(input, "ab🌊d", 4);
    expect(input.value).toBe("ab🌊d");
    typed(input, "ab🌊de", 5);
    typed(input, "aXb🌊de", 2);
    expect(input.value).toBe("ab🌊de");
    expect(input.selectionEnd).toBe(1);
    typed(input, "ade", 1);
    typed(input, "a1234de", 5);
    expect(input.value).toBe("a12de");
    expect(input.selectionEnd).toBe(3);
  });
});

describe("savedChoice", () => {
  test("a pick refused says why and shows again what is stored", async () => {
    const notice = el("div");
    const choice = savedChoice("Figure", [["woman", "Woman"], ["robot", "Robot"]], notice, async () => "woman", async () => Promise.reject(new Error("refused")));
    document.body.append(el("div", {}, choice.node));
    const pressed = () => [...document.querySelectorAll("button")].find((button) => button.ariaPressed === "true")?.textContent;
    await vi.waitFor(() => expect(pressed()).toBe("Woman"));
    document.querySelectorAll("button")[1].click();
    await vi.waitFor(() => expect(notice.textContent).toBe("Refused"));
    expect(pressed()).toBe("Woman");
  });

  test("of two picks in a row the last stands, though the first's answer comes after it", async () => {
    const answers: Record<string, number> = { robot: 30, woman: 0 };
    const save = (value: string) => new Promise<string>((done) => setTimeout(() => done(value), answers[value]));
    const choice = savedChoice("Figure", [["woman", "Woman"], ["robot", "Robot"]], el("div"), async () => "woman", save);
    document.body.replaceChildren(el("div", {}, choice.node));
    const pressed = () => [...document.querySelectorAll("button")].find((button) => button.ariaPressed === "true")?.textContent;
    await vi.waitFor(() => expect(pressed()).toBe("Woman"));
    document.querySelectorAll("button")[1].click();
    document.querySelectorAll("button")[0].click();
    await new Promise((over) => setTimeout(over, 60));
    expect(pressed()).toBe("Woman");
  });
});
