// The app's updates: Settings' check at once and its window for each answer, its switch for the checks by
// themselves, and those checks at start and once a day, which say only a newer version, in the notice; "Update and
// restart" installs it. A browser has neither line nor check (the desktop app and the settings stand-ins).
import { afterEach, describe, expect, test, vi } from "vitest";
import { getSettings } from "../api/client";
import { desktop, inDesktop } from "../desktop";
import { toast } from "../dom";
import { DAY, updateLines, watchUpdates } from "./update";

vi.mock("../api/client", () => ({ getSettings: vi.fn(), changeSettings: vi.fn() }));
vi.mock("../desktop", () => ({ inDesktop: vi.fn(), desktop: vi.fn() }));

const settled = () => new Promise((done) => setTimeout(done, 0));

/** The desktop app answers the check with `checked` (an updater's error as its text, as Tauri hands it) and installs without a word. */
function answers(checked: unknown): void {
  vi.mocked(inDesktop).mockReturnValue(true);
  vi.mocked(desktop).mockImplementation((command) => (command === "update_check" ? (typeof checked === "string" || checked instanceof Error ? Promise.reject(checked) : Promise.resolve(checked)) : Promise.resolve()));
}

async function check(home: HTMLElement): Promise<HTMLDialogElement> {
  vi.mocked(getSettings).mockResolvedValue({ check_updates: true } as never);
  const { lines } = updateLines(() => home)!;
  home.append(...lines);
  lines[0].querySelector("button")!.click();
  await settled();
  return home.querySelector("dialog")!;
}

const buttons = (box: HTMLElement) => [...box.querySelectorAll(".dialog-foot button")].map((button) => button.textContent);

afterEach(() => {
  vi.useRealTimers();
  vi.mocked(desktop).mockReset();
  document.body.replaceChildren();
});

describe("the check at once", () => {
  test("a newer version shows both versions and the notes, and Update and restart installs it", async () => {
    answers({ current: "0.1.0", latest: "0.2.0", notes: "Lorebooks for personas" });
    document.body.append(Object.assign(document.createElement("div"), { id: "toast" }));
    const box = await check(document.createElement("div"));
    expect(box.querySelector("h2")!.textContent).toBe("Cardwave 0.2.0 is available");
    expect(box.querySelector(".update-body")!.textContent).toBe("You have 0.1.0.What's newLorebooks for personas");
    expect(buttons(box)).toEqual(["Update and restart", "Close"]);
    box.querySelector<HTMLButtonElement>(".primary")!.click();
    expect(desktop).toHaveBeenCalledWith("update_install");
    expect(box.open).toBe(false);
    expect(toast().textContent).toBe("Downloading Cardwave 0.2.0…");
  });

  test("up to date or failed, it says so with OK alone", async () => {
    answers({ current: "0.1.0", latest: null, notes: null });
    let box = await check(document.createElement("div"));
    expect([box.querySelector("h2")!.textContent, box.querySelector(".update-body")!.textContent]).toEqual(["Check for updates", "Cardwave is up to date (0.1.0)."]);
    expect(buttons(box)).toEqual(["OK"]);
    answers("error sending request for url (https://github.com/elana-voss/cardwave-next/releases/latest/download/latest.json)");
    box = await check(document.createElement("div"));
    expect([box.querySelector("h2")!.textContent, box.querySelector(".update-body")!.textContent]).toEqual(["Check for updates", "Couldn't check for updates. Check your connection."]);
    expect(buttons(box)).toEqual(["OK"]);
  });

  test("a failure with a working connection is not told as the connection's", async () => {
    answers("Could not fetch a valid release JSON from the remote");
    const box = await check(document.createElement("div"));
    expect(box.querySelector(".update-body")!.textContent).not.toMatch(/connection/);
    expect(box.querySelector(".update-body")!.textContent).toMatch(/^Couldn't check for updates: GitHub/);
  });

  test("while it checks, the button says so", async () => {
    let answer: (found: unknown) => void = () => {};
    vi.mocked(inDesktop).mockReturnValue(true);
    vi.mocked(desktop).mockImplementation(() => new Promise((done) => (answer = done)));
    const home = document.createElement("div");
    const button = (await check(home), home.querySelector<HTMLButtonElement>(".item button")!);
    expect([button.textContent, button.disabled]).toEqual(["Checking…", true]);
    answer({ current: "0.1.0", latest: null, notes: null });
    await settled();
    expect([button.textContent, button.disabled]).toEqual(["Check", false]);
  });

  test("a browser has neither line", () => {
    vi.mocked(inDesktop).mockReturnValue(false);
    expect(updateLines(() => document.body)).toBeNull();
  });
});

describe("the checks by themselves", () => {
  test("the switch shows the setting", async () => {
    answers(null);
    vi.mocked(getSettings).mockResolvedValue({ check_updates: false } as never);
    const { lines } = updateLines(() => document.body)!;
    await settled();
    expect(lines[1].textContent).toContain("Check automatically");
    expect(lines[1].querySelector<HTMLInputElement>("input")!.checked).toBe(false);
  });

  test("at start and once a day a newer version is told in the notice, with Update and restart", async () => {
    vi.useFakeTimers();
    answers({ current: "0.1.0", latest: null, notes: null });
    document.body.append(Object.assign(document.createElement("div"), { id: "toast" }));
    vi.mocked(getSettings).mockResolvedValue({ check_updates: true } as never);
    watchUpdates();
    await vi.advanceTimersByTimeAsync(0);
    expect(toast().textContent).toBe("");
    answers({ current: "0.1.0", latest: "0.2.0", notes: null });
    await vi.advanceTimersByTimeAsync(DAY);
    expect(toast().textContent).toBe("Cardwave 0.2.0 is availableUpdate and restart");
    toast().querySelector("button")!.click();
    await vi.advanceTimersByTimeAsync(0);
    expect(desktop).toHaveBeenCalledWith("update_install");
  });

  test("switched off, or in a browser, nothing is asked; a failure says nothing", async () => {
    answers(new Error("offline"));
    document.body.append(Object.assign(document.createElement("div"), { id: "toast" }));
    vi.mocked(getSettings).mockResolvedValue({ check_updates: true } as never);
    watchUpdates();
    await settled();
    expect(toast().textContent).toBe("");
    vi.mocked(desktop).mockClear();
    vi.mocked(getSettings).mockResolvedValue({ check_updates: false } as never);
    watchUpdates();
    await settled();
    vi.mocked(inDesktop).mockReturnValue(false);
    watchUpdates();
    await settled();
    expect(desktop).not.toHaveBeenCalled();
  });
});
