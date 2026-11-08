import { describe, expect, it } from "vitest";
import type { Hit } from "../api/generated/Hit";
import { addressOf, grouped, pageHits, shown } from "./find";

const hit = (more: Partial<Hit>): Hit => ({ kind: "character", id: 3, name: "Mira", line: "", picture: null, book: null, part: null, names: [], known: null, when: null, ...more });

describe("Search Cardwave's hits", () => {
  it("open their page: a lorebook on its entry, a card's own in the card, a listed one on its list", () => {
    expect(addressOf(hit({}))).toBe("#/library/3");
    expect(addressOf(hit({ kind: "lorebook" }))).toBe("#/library/lorebooks/3");
    expect(addressOf(hit({ kind: "lorebook", part: "lore.gulls" }))).toBe("#/library/lorebooks/3/lore.gulls");
    expect(addressOf(hit({ kind: "lorebook", book: "", part: "lore.wreck" }))).toBe("#/library/3/lorebook/lore.wreck");
    expect(addressOf(hit({ kind: "lorebook", book: "lorebook.coast" }))).toBe("#/library/3/lorebook.coast");
    expect(addressOf(hit({ kind: "chat", id: 12 }))).toBe("#/chats/12");
    expect([shown(hit({ kind: "persona", name: "Rell" }))].map((one) => [one.address, one.reveal])).toEqual([["#/library/personas", "Rell"]]);
    expect(shown(hit({ kind: "memory", name: "The user is afraid." })).address).toBe("#/knowledge/memories");
    expect(shown(hit({ kind: "document", name: "Notes.txt" })).reveal).toBe("Notes.txt");
  });

  it("say of a memory who knows it", () => {
    expect(shown(hit({ kind: "memory", known: { code: "by", names: ["Mira"], you: true } })).line).toBe("Known by Mira and you");
    expect(shown(hit({ kind: "memory", known: { code: "by", names: [], you: false } })).line).toBe("Known by nobody");
    expect(shown(hit({ kind: "memory", known: { code: "everyone" } })).line).toBe("Known by everyone");
  });

  it("call a chat as among the latest chats, and say how long ago it was written in", () => {
    const chat = shown(hit({ kind: "chat", name: "Storm night", names: ["Mira"], when: Date.now() }));
    expect(chat.name).toBe("Mira · Storm night");
    expect(chat.line).toBe("Today");
  });

  it("find the app's pages by their names and its settings by their labels, in every case", () => {
    const voices = pageHits("VOICES");
    expect(voices[0]).toMatchObject({ kind: "page", name: "Settings › Voices", line: "Settings", address: "#/settings/voices", reveal: null });
    expect(pageHits("settings voices").map((one) => one.name)).toContain("Settings › Voices");
    expect(pageHits("")).toEqual([]);
    expect(pageHits("nothing like it")).toEqual([]);
    // The first eight words count, as on the server.
    expect(pageHits("settings voices voices voices voices voices voices voices nine").map((one) => one.name)).toContain("Settings › Voices");
  });

  it("are grouped in the order of the kinds, a group only where it has hits", () => {
    const hits = [shown(hit({ kind: "persona" })), ...pageHits("trash"), shown(hit({}))];
    expect(grouped(hits).map(([heading, of]) => [heading, of.length])).toEqual([
      ["Characters", 1],
      ["Personas", 1],
      ["Pages", 2],
    ]);
  });
});

describe("Search Cardwave's settings", () => {
  it("are the labels the pages draw, with those the server lists, by page", () => {
    expect(pageHits("export format")).toMatchObject([{ name: "Export format", line: "Settings › Advanced", address: "#/settings/advanced", reveal: "Export format" }]);
    expect(pageHits("alba")).toEqual([]);
    expect(pageHits("alba", { "#/settings/voices": ["Alba"] })).toMatchObject([{ name: "Alba", line: "Settings › Voices", address: "#/settings/voices", reveal: "Alba" }]);
  });

  it("are not offered to another account where they are this computer's account's alone: Sharing, Backup, Restore, This computer", () => {
    const of = (query: string, local: boolean) => pageHits(query, {}, local).map((one) => one.name);
    for (const query of ["sharing", "home network", "backup", "restore"]) {
      expect(of(query, true), query).not.toEqual([]);
      expect(of(query, false), query).toEqual([]);
    }
  });
});
