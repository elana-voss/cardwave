import type { Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import { expect, test } from "../test";

// The 3D figures' renderer (web/src/figures/drawer.ts): WebGPU where the browser offers an adapter, WebGL 2 where
// it does not, chosen by itself. Playwright's headless shell finds no device (it lacks dxcompiler.dll), so this file
// starts the full Chromium (`channel: "chromium"`, its new headless mode) with the flags below, as the mixamo viewer's
// tools/snap.mjs starts it; the fallback is forced by a page whose `requestAdapter` finds none. Each path draws the companion's figure, whose
// drawn pixels tell the desktop app where the cursor is on it (`companionCursor`, answered by `companion_over`
// through a stand-in of the desktop app), and a card's figure still from a file (e2e/figures/mannequin.vrm).
// The console names the path taken ("renderer: WebGPU" or "renderer: WebGL 2"). The still comes first, as the
// stand-in of the desktop app the companion's page is given would make the app's page take itself for the desktop.

test.use({ channel: "chromium", launchOptions: { args: ["--enable-unsafe-webgpu", "--enable-gpu", "--use-angle=d3d11"] } });

/** The paths the renderer told the console of, in order. */
function paths(page: Page): string[] {
  const told: string[] = [];
  page.on("console", (message) => {
    const path = /^renderer: (.+)$/.exec(message.text());
    if (path) told.push(path[1]!);
  });
  return told;
}

/** Has the page's WebGPU find no adapter, as in a browser without it. */
async function withoutWebGPU(page: Page): Promise<void> {
  await page.addInitScript(() => {
    if (navigator.gpu) navigator.gpu.requestAdapter = () => Promise.resolve(null);
  });
}

/** The companion's figure is drawn, the cursor on it is over it and off it in a corner is not, and the canvas is `kind`'s. */
async function companionDrawn(page: Page, kind: "webgpu" | "webgl2"): Promise<void> {
  await page.addInitScript(() => {
    const told: boolean[] = [];
    Object.assign(window, { told, __TAURI_INTERNALS__: { invoke: (command: string, args: { over?: boolean }) => Promise.resolve(void (command === "companion_over" && told.push(args.over!))) } });
  });
  await page.goto("/companion.html");
  const figure = page.locator("canvas.companion-figure");
  await expect(figure).toBeVisible();
  // Once the figure is drawn, some point of its canvas is on it; the canvas is found anew each time, as the figure
  // lands on the floor first.
  await expect
    .poll(() =>
      figure.evaluate((canvas: HTMLCanvasElement) => {
        const { x, y, width, height } = canvas.getBoundingClientRect();
        const call = (window as unknown as { companionCursor: (x: number, y: number) => void }).companionCursor;
        for (let i = 1; i < 20; i++) for (let j = 1; j < 20; j++) call(x + (width * i) / 20, y + (height * j) / 20);
        return (window as unknown as { told: boolean[] }).told.includes(true);
      }),
    )
    .toBe(true);
  await figure.evaluate((canvas: HTMLCanvasElement) => {
    const { x, y } = canvas.getBoundingClientRect();
    (window as unknown as { companionCursor: (x: number, y: number) => void }).companionCursor(x + 1, y + 1);
  });
  expect(await page.evaluate(() => (window as unknown as { told: boolean[] }).told.at(-1))).toBe(false);
  // A canvas gives only the kind of drawing it was first asked for.
  expect(await figure.evaluate((canvas: HTMLCanvasElement, other) => canvas.getContext(other) === null, kind === "webgpu" ? "webgl2" : "webgpu")).toBe(true);
}

/** Adds mannequin.vrm to a new card from a file: its still is drawn, the figure in it. */
async function stillDrawn(page: Page): Promise<void> {
  const data = { title: "Mira", tags: [], creator: "", name: "Mira", greetings: ["Hello."], description: "", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await page.request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  await page.goto(`/#/library/${(await made.json()).card_id}`);
  await page.getByRole("button", { name: "Character menu", exact: true }).click();
  await page.getByRole("menuitem", { name: "Add a 3D figure" }).click();
  const chooser = page.waitForEvent("filechooser");
  await page.getByRole("dialog", { name: "Add a 3D figure" }).getByRole("button", { name: "From a file…" }).click();
  await (await chooser).setFiles({ name: "mannequin.vrm", mimeType: "application/octet-stream", buffer: readFileSync("figures/mannequin.vrm") });
  const still = page.locator("img.fig-small");
  await expect.poll(() => still.evaluate((image: HTMLImageElement) => (image.complete ? image.naturalWidth : 0))).toBe(192);
  const opaque = await still.evaluate((image: HTMLImageElement) => {
    const draw = Object.assign(document.createElement("canvas"), { width: 192, height: 192 }).getContext("2d")!;
    draw.drawImage(image, 0, 0);
    return draw.getImageData(0, 0, 192, 192).data.filter((_, i) => i % 4 === 3 && _ > 16).length;
  });
  expect(opaque).toBeGreaterThan(1000);
}

test("where the browser offers WebGPU, the figures are drawn through it", async ({ page }) => {
  const told = paths(page);
  await stillDrawn(page);
  await companionDrawn(page, "webgpu");
  expect(told).toEqual(["WebGPU", "WebGPU"]);
});

test("where the browser offers no WebGPU, the figures are drawn through WebGL 2", async ({ page }) => {
  const told = paths(page);
  await withoutWebGPU(page);
  await stillDrawn(page);
  await companionDrawn(page, "webgl2");
  expect(told).toEqual(["WebGL 2", "WebGL 2"]);
});
