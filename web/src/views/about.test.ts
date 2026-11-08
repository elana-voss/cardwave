import { describe, expect, it, vi } from "vitest";
import { getWhatsNew } from "../api/client";
import { found, spoken, versions } from "./about";

describe("the page About Cardwave", () => {
  it("shows what each version brought, in the file's order, its points as a list and its links as links", () => {
    const all = versions("Before any.\n# 0.2.0\n\nSome words.\n- One\n- Two, see https://example.com\n\nAfter.\n## Fixed\n- Three\n# 0.1.0\nFirst.\n");
    expect(all.map((one) => one.version)).toEqual(["0.2.0", "0.1.0"]);
    expect(all[0]!.notes.map((part) => part.tagName)).toEqual(["P", "UL", "P", "H4", "UL"]);
    expect(all[0]!.notes[1]!.querySelectorAll("li")).toHaveLength(2);
    expect(all[0]!.notes[1]!.querySelector("a")?.getAttribute("href")).toBe("https://example.com");
    expect(all[1]!.notes.map((part) => part.textContent)).toEqual(["First."]);
    expect(versions("\n  \n")).toEqual([]);
  });

  it("says a license's expression in words", () => {
    expect(spoken("MIT OR Apache-2.0")).toBe("MIT or Apache-2.0");
    expect(spoken("MIT/Apache-2.0")).toBe("MIT or Apache-2.0");
    expect(spoken("Apache-2.0 / MIT")).toBe("Apache-2.0 or MIT");
    expect(spoken("(MIT OR Apache-2.0) AND Unicode-3.0")).toBe("(MIT or Apache-2.0) and Unicode-3.0");
    expect(spoken("Apache-2.0 WITH LLVM-exception")).toBe("Apache-2.0 with LLVM-exception");
  });

  it("finds the libraries by a part of their name, whatever its case", () => {
    const library = (name: string) => ({ name, version: "1.0.0", license: "MIT", texts: [0] });
    const all = [library("axum"), library("axum-extra"), library("Image"), library("three")];
    expect(found(all, " AXUM ").map((one) => one.name)).toEqual(["axum", "axum-extra"]);
    expect(found(all, "image").map((one) => one.name)).toEqual(["Image"]);
    expect(found(all, "")).toEqual(all);
    expect(found(all, "nothing")).toEqual([]);
  });
});

describe("the notes' file", () => {
  it("is no notes where the server answers the UI's page in its place", async () => {
    vi.stubGlobal("fetch", async () => new Response("<!doctype html><html></html>", { headers: { "content-type": "text/html; charset=utf-8" } }));
    expect(await getWhatsNew()).toBe("");
    vi.stubGlobal("fetch", async () => new Response("# 0.1.0", { headers: { "content-type": "text/markdown" } }));
    expect(await getWhatsNew()).toBe("# 0.1.0");
    vi.unstubAllGlobals();
  });

  it("is the language's own, the English where the language has none", async () => {
    const files: Record<string, string> = { "/whats-new.md": "# 0.1.0 English", "/whats-new.de.md": "# 0.1.0 Deutsch" };
    vi.stubGlobal("fetch", async (url: string) =>
      url in files ? new Response(files[url], { headers: { "content-type": "text/markdown" } }) : new Response("<html></html>", { headers: { "content-type": "text/html" } }));
    expect([await getWhatsNew("de"), await getWhatsNew("ja"), await getWhatsNew("en")]).toEqual(["# 0.1.0 Deutsch", "# 0.1.0 English", "# 0.1.0 English"]);
    vi.unstubAllGlobals();
  });
});
