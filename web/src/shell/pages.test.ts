import { expect, it } from "vitest";
import { pageHits } from "./find";
import { pageAt } from "./pages";
import { accountPages } from "./rail";

it("names a page by the start of its address that matches longest, the list of chats for what the app does not know", () => {
  const at = (address: string) => [pageAt(address).name, pageAt(address).shape];
  expect(at("#/chats/12/tasks/3")).toEqual(["Coding task", "code"]);
  expect(at("#/library/3/lorebook.coast")).toEqual(["Lorebook", "lorebook"]);
  expect(at("#/library/3")).toEqual(["Character", "person"]);
  expect(at("#/settings/advanced/prompts/new")).toEqual(["Prompt preset", "gear"]);
  // About is told from Settings' pages in the tabs by its own icon.
  expect(at("#/settings/about")).toEqual(["About Cardwave", "info"]);
  expect(at("#/knowledge")).toEqual(["Memories", "knowledge"]);
  expect(at("#/nowhere")).toEqual(["Chats", "chat"]);
});

it("draws a page alike in the search, the tabs and the rail: the characters as a person", () => {
  expect(pageHits("characters")[0]).toMatchObject({ name: "Library › Characters", line: "Library", shape: "person" });
  expect(pageAt("#/library").shape).toBe("person");
  expect(pageHits("css")[0]).toMatchObject({ name: "Settings › Advanced › Cardwave's CSS", line: "Settings" });
  expect(accountPages()).toEqual([
    ["Profile", "#/account/profile", "person"],
    ["Settings", "#/settings", "gear"],
    ["Sharing", "#/account/server", "server"],
  ]);
});
