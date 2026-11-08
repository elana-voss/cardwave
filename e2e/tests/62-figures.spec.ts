import { readFileSync } from "node:fs";
import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { pictureFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// 3D figures (boards "Card page · expressions and 3D figure", "Add a 3D figure"): a VRM from a file put on a card,
// drawn for its still, taken off with Undo and chosen for another card; a figure whose skeleton is not a human's
// refused; a mode's own figure, from an FBX; and the companion window showing the figure of its card's mode, asked
// again after a reply. The figures are tools/test-figures.py's mannequins (e2e/figures/). That the carrier's clips
// move them is web/src/figures/retarget.test.ts's; here the companion asks for the figure's file and draws it.

let api: FakeProvider;
test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

const figureFile = (name: string) => readFileSync(`figures/${name}`);

/** A card of `name`, with the modes `modes`: its number. */
async function newCard(request: APIRequestContext, name: string, modes: string[] = []): Promise<number> {
  const data = { title: name, tags: [], creator: "", name, greetings: ["Hello."], description: "", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const id = (await made.json()).card_id;
  if (modes.length) {
    const edit = await (await request.get(`/api/cards/${id}/edit`)).json();
    expect((await request.put(`/api/cards/${id}/edit`, { data: { ...edit, modes } })).status()).toBe(200);
  }
  return id;
}

const part = (page: Page) => page.locator(".part", { has: page.getByRole("heading", { name: "3D figure" }) });

/** Opens "Add a 3D figure" by the card menu: a card without a figure shows no part for it. */
async function byMenu(page: Page): Promise<void> {
  await expect(page.getByRole("button", { name: "Character menu", exact: true })).toBeVisible();
  await expect(part(page)).toHaveCount(0);
  await page.getByRole("button", { name: "Character menu", exact: true }).click();
  await page.getByRole("menuitem", { name: "Add a 3D figure" }).click();
}

/** Picks `file` in "Add a 3D figure", opened by the card menu, for the card or the mode `mode`. */
async function fromFile(page: Page, file: string, mode?: string): Promise<void> {
  await byMenu(page);
  const adding = page.getByRole("dialog", { name: "Add a 3D figure" });
  await expect(adding.getByRole("button", { name: "From a file…" })).toBeEnabled();
  await expect(adding).toContainText("The figure the character appears as in the companion window.");
  if (mode) await adding.getByRole("group", { name: "Used for" }).getByRole("button", { name: mode }).click();
  const chooser = page.waitForEvent("filechooser");
  await adding.getByRole("button", { name: "From a file…" }).click();
  await (await chooser).setFiles({ name: file, mimeType: "application/octet-stream", buffer: figureFile(file) });
}

test("a figure from a file goes on a card, drawn for its still, comes off with Undo, and is chosen for another card", async ({ page, request }) => {
  const mira = await newCard(request, "Mira");
  const tom = await newCard(request, "Tom");
  await page.goto(`/#/library/${mira}`);
  await fromFile(page, "mannequin.vrm");
  await expect(page.getByRole("dialog", { name: "Add a 3D figure" })).toBeHidden();
  await expect(part(page).locator(".row")).toHaveText("mannequin");
  // The still drawn of it.
  const still = part(page).locator("img.fig-small");
  await expect.poll(() => still.evaluate((image: HTMLImageElement) => (image.complete ? image.naturalWidth : 0))).toBe(192);

  await part(page).getByRole("button", { name: "Remove mannequin from this character" }).click();
  await expect(page.locator("#toast")).toContainText("3D figure removed from this character.");
  await expect(part(page)).toContainText("None yet · Cardwave’s own figure stands in for the character");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(part(page).locator(".row")).toHaveText("mannequin");

  await page.goto(`/#/library/${tom}`);
  await byMenu(page);
  const adding = page.getByRole("dialog", { name: "Add a 3D figure" });
  const line = adding.getByRole("button", { name: /mannequin/ });
  // A figure is told by its name and who uses it, not by its file's format.
  await expect(line.locator(".meta")).toHaveText("used by 1 character");
  await expect(adding.getByRole("button", { name: "Add", exact: true })).toBeDisabled();
  await line.click();
  await expect(line).toHaveAttribute("aria-pressed", "true");
  await adding.getByRole("button", { name: "Add", exact: true }).click();
  await expect(part(page).locator(".row")).toHaveText("mannequin");
});

test("a figure without a human skeleton is refused, and nothing is kept", async ({ page, request }) => {
  const card = await newCard(request, "Odd");
  await page.goto(`/#/library/${card}`);
  await fromFile(page, "odd.glb");
  const adding = page.getByRole("dialog", { name: "Add a 3D figure" });
  await expect(adding.getByRole("alert")).toContainText("Cardwave cannot make this figure move");
  const held: { name: string }[] = await (await request.get("/api/figures")).json();
  expect(held.map(({ name }) => name)).not.toContain("odd");
});

test("a mode has its own figure, and the companion shows the figure of its chat's mode", async ({ page, request }) => {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const gwen = await newCard(request, "Gwen", ["Roleplay", "Assistant"]);
  await page.goto(`/#/library/${gwen}`);
  await fromFile(page, "mixamo.fbx", "Assistant");
  await expect(part(page).locator(".row")).toHaveText("mixamo · in Assistant");
  const given = await request.post(`/api/cards/${gwen}/figures`, {
    data: { file_name: "mannequin.vrm", data: figureFile("mannequin.vrm").toString("base64"), still: pictureFile([4, 4]).toString("base64"), mode: null },
  });
  expect(given.status(), await given.text()).toBe(200);
  const { figures } = await given.json();
  const [own, office] = [figures.figure.id, figures.modes[0].figure.id];

  // The companion is Gwen; her chat is in Roleplay, her first mode, which shows the card's figure.
  const shown = await (await request.get(`/api/cards/${gwen}`)).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: shown.card.version_id, character: shown.characters[0].id }] } });
  const chat = (await started.json()).chat.id;
  expect((await request.patch("/api/settings", { data: { companion: { card_id: gwen, starts: true, hidden_until: null } } })).status()).toBe(200);
  const warned: string[] = [];
  page.on("console", (message) => void (message.type() === "warning" && warned.push(message.text())));
  const file = (id: number) => page.waitForResponse((answer) => answer.url().endsWith(`/api/figures/${id}/file`) && answer.ok());
  const ownFile = file(own);
  await page.goto("/companion.html");
  await ownFile;
  const figure = page.locator("canvas.companion-figure");
  // Drawn: some pixel of the canvas is the figure's.
  await expect
    .poll(() =>
      figure.evaluate((canvas: HTMLCanvasElement) => {
        const copy = document.createElement("canvas");
        [copy.width, copy.height] = [canvas.width, canvas.height];
        const drawn = copy.getContext("2d")!;
        drawn.drawImage(canvas, 0, 0);
        return drawn.getImageData(0, 0, copy.width, copy.height).data.some((value, at) => at % 4 === 3 && value > 16);
      }),
    )
    .toBe(true);

  // Set to Assistant, the next reply has the companion show the mode's own.
  expect((await request.put(`/api/chats/${chat}/mode`, { data: { mode: "Assistant" } })).status()).toBe(200);
  api.moves([]);
  await figure.dblclick();
  const compact = page.getByRole("dialog", { name: "Chat with your companion" });
  const officeFile = file(office);
  await compact.getByPlaceholder("Message Gwen").fill("Back to work");
  await compact.getByPlaceholder("Message Gwen").press("Enter");
  await officeFile;
  await page.waitForTimeout(500);
  expect(warned.filter((text) => text.includes("did not load"))).toEqual([]);
});
