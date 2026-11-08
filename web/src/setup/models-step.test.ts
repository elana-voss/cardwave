// What first run downloads (`toDownload`), and what step 2 says of it under its box.
import type { ErrorBody } from "../api/generated/ErrorBody";
import { expect, test } from "vitest";
import { confirmText, toDownload, totalText } from "./models-step";

test("first run downloads what its switches chose, where it is not there, on this computer's account alone", () => {
  const of = (state: "absent" | "downloading" | "ready", failure: ErrorBody | null = null) => ({ name: "bge-m3", size: 10, state, done: 0, failure, left: 0 });
  const voice = { ...of("absent"), rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  const both = { voice: true, search: true };
  expect(toDownload(true, voice, of("ready"), both).map((one) => one.kind)).toEqual(["voice"]);
  // One downloading, or failed, is seen through too.
  expect(toDownload(true, { ...voice, state: "downloading" }, of("absent", { code: "download_failed", error: "no connection", details: {} }), both).map((one) => one.name)).toEqual(["Voice", "Search"]);
  expect(toDownload(true, { ...voice, state: "ready" }, of("ready"), both)).toEqual([]);
  expect(toDownload(false, voice, of("absent"), both)).toEqual([]);
  // As step 2 opens: the search model chosen, the voice not.
  expect(toDownload(true, voice, of("absent"), { voice: false, search: true }).map((one) => one.kind)).toEqual(["search"]);
  expect(toDownload(true, voice, of("absent"), { voice: false, search: false })).toEqual([]);
});

test("the line under the box names what the button downloads, the button its size in all, or that nothing is downloaded now", () => {
  const voice = { name: "Voice", size: 192_406_993 };
  const search = { name: "Search", size: 634_553_760 };
  expect(totalText([voice, search], true)).toBe("To download: Voice and Search.");
  expect(confirmText([voice, search])).toBe("Download (788.7 MB)");
  expect(totalText([search], true)).toBe("To download: Search.");
  expect(confirmText([search])).toBe("Download (605.2 MB)");
  expect(confirmText([])).toBe("Confirm");
  expect(totalText([], true)).toBe("Nothing is downloaded now. Search and Voice can be set up later in Settings.");
  // Nothing was there to download.
  expect(totalText([], false)).toBe("");
});
