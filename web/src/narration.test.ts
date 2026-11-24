// What narration.ts draws of a text's marks (marks.ts reads them, marks.test.ts): a message's paragraphs and
// quotation blocks, links and pictures, and the switch for pictures from the web.
import { expect, test, vi } from "vitest";
import { changeSettings } from "./api/client";
import type { Settings } from "./api/generated/Settings";
import { narrated, webPictures } from "./narration";

vi.mock("./api/client", () => ({ changeSettings: vi.fn() }));

test("a text is shown as its paragraphs, narration in italics, and reads back as written less the asterisks", () => {
  const shown = narrated('*She turns.* "Well?"\n\nSecond paragraph,\nsecond line.');
  const holder = document.createElement("div");
  holder.append(...shown);
  expect([...holder.children].map((child) => child.tagName)).toEqual(["P", "P"]);
  expect(holder.querySelector("em")!.textContent).toBe("She turns.");
  expect(holder.querySelectorAll("em")).toHaveLength(1);
  expect(holder.textContent).toBe('She turns. "Well?"\n\nSecond paragraph,\nsecond line.');
});

test("each mark as its element, speech in a span with its quotation marks, quotation blocks in a blockquote", () => {
  const holder = document.createElement("div");
  holder.append(...narrated('*a* **b** "c" <u>d</u> `e`\n> *f*\ng'));
  expect(holder.innerHTML).toBe('<p><em>a</em> <strong>b</strong> <span class="speech">"c"</span> <u>d</u> <code>e</code></p>\n<blockquote><p><em>f</em></p></blockquote>\n<p>g</p>');
});

test("narration does not reach from one paragraph into the next", () => {
  const holder = document.createElement("div");
  holder.append(...narrated("*one\n\ntwo*"));
  expect(holder.querySelectorAll("em")).toHaveLength(0);
  expect(holder.textContent).toBe("*one\n\ntwo*");
});

test("only the last paragraph of a text being written has narration that is not ended", () => {
  const holder = document.createElement("div");
  holder.append(...narrated("*one\n\n*two", true));
  expect([...holder.querySelectorAll("p")].map((p) => p.innerHTML)).toEqual(["*one", "<em>two</em>"]);
});

test("a text without words shows nothing", () => {
  expect(narrated("")).toEqual([]);
  expect(narrated("\n\n")).toEqual([]);
  expect(narrated(" \n \n ", true)).toEqual([]);
});

test("a paragraph without words is left out, and one before it stays ended", () => {
  const holder = document.createElement("div");
  holder.append(...narrated("\n\nfirst\n\n\n\nsecond"));
  expect([...holder.querySelectorAll("p")].map((p) => p.textContent)).toEqual(["first", "second"]);
  expect(holder.textContent).toBe("first\n\nsecond");
  // The empty line at the end is the paragraph being written: the one before it is not.
  holder.replaceChildren(...narrated("*one\n\n", true));
  expect([...holder.querySelectorAll("p")].map((p) => p.innerHTML)).toEqual(["*one"]);
});

test("a message's links open beside the app, its pictures show, and what is no web address stays text", () => {
  webPictures(true);
  const [p] = narrated("See [the map](https://example.com/map) or https://example.com/a. ![A lamp](https://example.com/lamp.png) [no](javascript:alert(1))") as HTMLElement[];
  const links = [...p.querySelectorAll("a")];
  expect(links.map((a) => [a.textContent, a.getAttribute("href"), a.target])).toEqual([
    ["the map", "https://example.com/map", "_blank"],
    ["https://example.com/a", "https://example.com/a", "_blank"],
  ]);
  const picture = p.querySelector("img")!;
  expect([picture.getAttribute("src"), picture.alt]).toEqual(["https://example.com/lamp.png", "A lamp"]);
  expect(p.textContent).toBe("See the map or https://example.com/a.  [no](javascript:alert(1))");
  // In narration too.
  const [told] = narrated("*She points at https://example.com.*") as HTMLElement[];
  expect(told.querySelector("em a")?.getAttribute("href")).toBe("https://example.com");
});

test("setting pictures from the web says whether that changed them", () => {
  webPictures(false);
  expect(webPictures(false)).toBe(false);
  expect(webPictures(true)).toBe(true);
  expect(webPictures(true)).toBe(false);
  expect(webPictures(false)).toBe(true);
});

test("the page loads again where the switch goes on that was off as it was loaded, as its policy holds them back", async () => {
  const reload = vi.fn();
  vi.stubGlobal("location", { origin: "http://localhost", reload });
  const page = async () => (vi.resetModules(), (await import("./narration")).webPictures);
  const offAtLoad = await page();
  offAtLoad(false);
  offAtLoad(true);
  expect(reload).toHaveBeenCalledTimes(1);
  const onAtLoad = await page();
  onAtLoad(true);
  onAtLoad(false);
  onAtLoad(true);
  expect(reload).toHaveBeenCalledTimes(1);
  vi.unstubAllGlobals();
});

test("while pictures from the web are off, one from another address is held back, and its button switches them on", async () => {
  webPictures(false);
  const own = `${location.origin}/api/x.png`;
  const [p] = narrated(`![A lamp](https://example.com/lamp.png) ![Mine](${own}) ![Dot](data:image/png;base64,AA==) ![Bad](http://)`) as HTMLElement[];
  document.body.replaceChildren(p);
  // Cardwave's own pictures show; the others say why they do not, and where it is changed.
  expect([...p.querySelectorAll("img")].map((img) => img.alt)).toEqual(["Mine", "Dot"]);
  const held = [...p.querySelectorAll<HTMLElement>(".web-picture")];
  expect(held.map((one) => one.dataset.alt)).toEqual(["A lamp", "Bad"]);
  expect(held[0].textContent).toContain("Settings › Appearance at any time");
  vi.mocked(changeSettings).mockResolvedValue({ web_pictures: true } as Settings);
  held[0].querySelector("button")!.click();
  expect(changeSettings).toHaveBeenCalledWith({ web_pictures: true });
  // Every picture held back on the page shows, and so does each drawn after.
  await vi.waitFor(() => expect(p.querySelectorAll(".web-picture")).toHaveLength(0));
  expect([...p.querySelectorAll("img")].map((img) => img.alt)).toEqual(["A lamp", "Mine", "Dot", "Bad"]);
  expect((narrated("![Later](https://example.com/b.png)")[0] as HTMLElement).querySelector("img")?.alt).toBe("Later");
});

test("a quotation block without words is left out, and the block before it is the one being written", () => {
  const holder = document.createElement("div");
  holder.append(...narrated("one\n\n>"));
  expect(holder.innerHTML).toBe("<p>one</p>");
  holder.replaceChildren(...narrated("*one\n>", true));
  expect(holder.innerHTML).toBe("<p><em>one</em></p>");
});
