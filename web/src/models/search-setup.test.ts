// What the line "Search" and its dialog say of the search model in each of its states; in first run, the
// download's size on this computer's account alone (the account and the server stand-ins).
import { describe, expect, test, vi } from "vitest";
import { account } from "../account";
import { getSearchModel } from "../api/client";
import type { SearchModel } from "../api/generated/SearchModel";
import { dialogSays, lineSays, searchLine } from "./search-setup";

vi.mock("../account", () => ({ account: vi.fn() }));
vi.mock("../api/client", () => ({ getSearchModel: vi.fn() }));

const model = (state: SearchModel["state"], more: Partial<SearchModel> = {}): SearchModel => ({
  name: "bge-m3",
  size: 634_553_760,
  state,
  done: 0,
  failure: null,
  left: 0,
  ...more,
});

describe("the search model", () => {
  test("not downloaded, it is set up from the line and downloaded from the dialog", () => {
    expect(lineSays(model("absent"))).toEqual({ says: "Not set up", action: "Set up" });
    expect(lineSays(model("absent"), true)).toEqual({ says: "Finds characters by what they are about · 605.2 MB download · recommended", action: "Change" });
    expect(dialogSays(model("absent"))).toEqual({ state: "Not downloaded", action: "Download" });
  });

  test("while it downloads both say how far in whole hundredths, and the dialog cancels it", () => {
    const downloading = model("downloading", { done: 634_553_760 * 0.649 });
    expect(lineSays(downloading)).toEqual({ says: "bge-m3 · downloading 64%", action: "Change" });
    expect(dialogSays(downloading)).toEqual({ state: "64%", action: "Cancel" });
  });

  test("ready, it says how many cards it has yet to read, and the dialog removes it", () => {
    expect(lineSays(model("ready", { left: 12 }))).toEqual({ says: "bge-m3 · This computer · reading characters, 12 left", action: "Change" });
    expect(dialogSays(model("ready", { left: 12 }))).toEqual({ state: "Reading characters · 12 left", action: "Remove" });
    expect(lineSays(model("ready"))).toEqual({ says: "bge-m3 · This computer", action: "Change" });
    expect(dialogSays(model("ready"))).toEqual({ state: "Ready", action: "Remove" });
  });
});

test("in first run another account's line says nothing of a download, as only this computer's account downloads", async () => {
  vi.mocked(getSearchModel).mockResolvedValue(model("absent"));
  const says = async (local: boolean) => {
    vi.mocked(account).mockResolvedValue({ local } as Awaited<ReturnType<typeof account>>);
    const line = searchLine(() => document.body, { changed: () => {} });
    line.read();
    await new Promise((settle) => setTimeout(settle, 10));
    return line.node.querySelector(".item-text > .meta")!.textContent;
  };
  expect(await says(true)).toBe("Finds characters by what they are about · 605.2 MB download · recommended");
  expect(await says(false)).not.toMatch(/download/);
});
