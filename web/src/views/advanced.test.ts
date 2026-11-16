import { describe, expect, it, vi } from "vitest";
import { changeSettings, getSettings, getSampling } from "../api/client";
import { describeCost, describingSays, plainGroup, samplingPart, SAMPLING, valueOf } from "./advanced";

vi.mock("../api/client", () => ({ getSampling: vi.fn(), setSampling: vi.fn(), getSettings: vi.fn(), changeSettings: vi.fn() }));

const of = (key: string) => SAMPLING.find((value) => value.key === key)!;

describe("the page Advanced", () => {
  it("says that describing all again was stopped part way, not that every character is described", () => {
    const again = { characters: 4, waiting: 0, done: 2, failed: 0, failure: null, stopped: true };
    expect(describingSays({ waiting: 0, left: 0, failed: 0, failure: null }, again)).toBe("Stopped at 2 of 4 described again");
    // A full run that a character came after, or describing the cards running, is not told as stopped.
    expect(describingSays({ waiting: 0, left: 1, failed: 0, failure: null }, { ...again, stopped: false })).not.toContain("Stopped");
    expect(describingSays({ waiting: 3, left: 3, failed: 0, failure: null }, again)).not.toContain("Stopped");
  });

  it("says what describing the characters not yet described costs, and nothing while it runs or with none left", () => {
    expect(describeCost({ waiting: 0, left: 503, failed: 0, failure: null })).toBe("Cards to read: 503");
    expect(describeCost({ waiting: 3, left: 3, failed: 0, failure: null })).toBe("");
    expect(describeCost({ waiting: 0, left: 0, failed: 0, failure: null })).toBe("");
  });

  it("keeps a value as typed only where it is a number in its range", () => {
    expect(valueOf("0.7", of("temperature"))).toBe(0.7);
    expect(valueOf(" 0,7 ", of("temperature"))).toBe(0.7);
    expect(valueOf("", of("temperature"))).toBeNull();
    expect(valueOf("2.5", of("temperature"))).toBeUndefined();
    expect(valueOf("abc", of("top_p"))).toBeUndefined();
    expect(valueOf("−1.5", of("presence_penalty"))).toBe(-1.5);
    expect(valueOf("3.5", of("seed"))).toBeUndefined();
    expect(valueOf("256", of("context_size"))).toBeUndefined();
    expect(valueOf("8192", of("context_size"))).toBe(8192);
  });

  it("keeps the sampling fields shut until the stored values have been read, so a value typed does not clear the others", async () => {
    vi.mocked(getSampling).mockRejectedValueOnce(new Error("not reached"));
    const part = samplingPart();
    const inputs = () => [...part.node.querySelectorAll("input")];
    await part.read();
    expect(inputs().every((input) => input.disabled)).toBe(true);
    vi.mocked(getSampling).mockResolvedValueOnce({ context_size: 8192, temperature: 0.7, top_p: null, frequency_penalty: null, presence_penalty: null, seed: null });
    await part.read();
    expect(inputs().some((input) => input.disabled)).toBe(false);
    expect(inputs()[1].value).toBe("0.7");
  });

  it("saves the text of \"Chat without a character\" when the page is left with the field still in focus", async () => {
    vi.mocked(getSettings).mockResolvedValue({ plain_prompt: "old" } as never);
    vi.mocked(changeSettings).mockResolvedValue({ plain_prompt: "new" } as never);
    const part = plainGroup();
    await vi.waitFor(() => expect(part.node.querySelector("textarea")!.disabled).toBe(false));
    part.node.querySelector("textarea")!.value = "new";
    part.left();
    await vi.waitFor(() => expect(changeSettings).toHaveBeenCalledWith({ plain_prompt: "new" }));
  });
});
