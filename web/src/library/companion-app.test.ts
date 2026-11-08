import { describe, expect, it, vi } from "vitest";

// What the settings answer, and how a change is taken: a test sets them.
const server = {
  settings: (): Promise<unknown> => Promise.resolve({ companion: { card_id: 3, starts: true, hidden_until: null, size: 21 } }),
  change: (_: unknown): Promise<unknown> => Promise.resolve({}),
};
vi.mock("../api/client", () => ({
  getSettings: () => server.settings(),
  changeCompanion: (change: unknown) => server.change(change),
}));
vi.mock("../desktop", () => ({ inDesktop: () => true, desktop: () => Promise.reject(new Error("refused")) }));

describe("the companion as the app starts", () => {
  it("is asked for where the settings say so, and a refusal is no error of the page", async () => {
    const failures: unknown[] = [];
    const caught = (reason: unknown) => void failures.push(reason);
    process.on("unhandledRejection", caught);
    const { startCompanion } = await import("./companion-app");
    startCompanion();
    await new Promise((done) => setTimeout(done, 20));
    process.off("unhandledRejection", caught);
    expect(failures).toEqual([]);
  });
});

describe("the companion's size", () => {
  it("is not put back by the reading after a refused change once the slider has moved on", async () => {
    const { sizeLine } = await import("./companion-app");
    const line = sizeLine(document.createElement("div"))!;
    const slider = line.node.querySelector("input")!;
    await vi.waitFor(() => expect(slider.disabled).toBe(false));
    // The change to 30 is refused, and the settings read after it answer late, with 21.
    let answer: (value: unknown) => void = () => {};
    server.change = (change) => ((change as { size: number }).size === 30 ? Promise.reject(new Error("refused")) : Promise.resolve({}));
    server.settings = () => new Promise((done) => (answer = done));
    const move = (size: number) => {
      slider.value = String(size);
      slider.dispatchEvent(new Event("input"));
    };
    move(30);
    await new Promise((done) => setTimeout(done, 0));
    move(45);
    answer({ companion: { card_id: 3, starts: true, hidden_until: null, size: 21 } });
    await new Promise((done) => setTimeout(done, 10));
    expect(slider.value).toBe("45");
  });
});
