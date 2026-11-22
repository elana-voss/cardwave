import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { basename } from "node:path";
import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { setSettings } from "../stored";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { headAndHand, watchFigure } from "../figure";

// A figure seen, not a test (runs only with SEEN set, as the run-throughs with RUN_THROUGHS=1; never by npm test or
// tools/check.sh): SEEN=<figure>,<figure>… names each, a built-in one (woman, man, robot) or a figure file's path from
// e2e/ (.glb, .vrm, .fbx), never written into the repo. A file is added as a card's figure through "Add a 3D figure",
// its still drawn; then the companion's page (the fake provider, the page's clock held, its chance fixed): the figure
// at rest, each feeling, its mouth's shapes while its bubble speaks and after, and a click on its head's crown and one
// on its left hand, each told to the steering model and answered in its bubble. Pictures and `<figure>.txt` (what was
// told, the mouth, the page's errors) go to SEEN_OUT (default ../.checklists/seen); each summary line is printed.
// One built-in figure and one of the user's, once: a figure file takes minutes under software WebGL.
// Run: cd e2e && SEEN=woman,../test-figures/vrm-pack/model/Aera.vrm npx playwright test 97-seen

const OUT = process.env.SEEN_OUT ?? "../.checklists/seen";
const BUILT_IN = ["woman", "man", "robot"];
const FIGURES = (process.env.SEEN ?? "").split(",").filter(Boolean);
/** Shape names that open the mouth: ARKit's, VRM's, DAZ's and Mixamo's. */
const MOUTH = /jawopen|mth_a$|(^|[._])a$|aa$/i;

let api: FakeProvider;
test.beforeAll(async () => void (api = await startFakeProvider()));
test.afterAll(() => api.close());

/** Adds the figure file `path` to the card `id` as its figure, through the card page, and keeps its still. */
async function addFigure(page: Page, id: number, path: string, name: string): Promise<void> {
  const adder = await page.context().newPage();
  await adder.goto(`/#/library/${id}`);
  await adder.getByRole("button", { name: "Character menu", exact: true }).click();
  await adder.getByRole("menuitem", { name: "Add a 3D figure" }).click();
  const chooser = adder.waitForEvent("filechooser");
  await adder.getByRole("dialog", { name: "Add a 3D figure" }).getByRole("button", { name: "From a file…" }).click();
  await (await chooser).setFiles({ name: basename(path), mimeType: "application/octet-stream", buffer: readFileSync(path) });
  const part = adder.locator(".part", { has: adder.getByRole("heading", { name: "3D figure" }) });
  // Its name, and the maker's credit where the file has one.
  await expect(part.locator(".row")).toContainText(basename(path).replace(/\.\w+$/, ""), { timeout: 120_000 });
  const still = part.locator("img.fig-small");
  await expect.poll(() => still.evaluate((i: HTMLImageElement) => (i.complete ? i.naturalWidth : 0)), { timeout: 60_000 }).toBeGreaterThan(0);
  await still.screenshot({ path: `${OUT}/${name}-still.png` });
  await adder.close();
}

/** How far open the figure's mouth is drawn now, its widest mouth shape (0 to 1). */
const mouth = (page: Page): Promise<number> =>
  page.evaluate((source) => {
    const open = new RegExp(source, "i");
    let widest = 0;
    for (const scene of (window as any).__figure.scenes)
      scene.traverse((o: any) => {
        for (const [key, at] of Object.entries((o.morphTargetDictionary ?? {}) as Record<string, number>))
          if (open.test(key)) widest = Math.max(widest, o.morphTargetInfluences[at] ?? 0);
      });
    return +widest.toFixed(2);
  }, MOUTH.source);

/** Has the companion do `steps` through its interface. */
async function act(request: APIRequestContext, steps: unknown[]): Promise<void> {
  const acted = await request.post("/api/companion/act", { data: { steps } });
  expect(acted.status(), await acted.text()).toBe(200);
}

for (const figure of FIGURES) {
  const name = BUILT_IN.includes(figure) ? figure : basename(figure);
  test(`seen ${name}`, async ({ page, request }) => {
    test.setTimeout(1_500_000);
    mkdirSync(OUT, { recursive: true });
    const lines: string[] = [];
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(String(e)));
    await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
    const data = { title: "Seen", tags: [], creator: "", name: "Seen", greetings: ["Hello."], description: "", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
    const id = (await (await request.post("/api/cards/new", { data })).json()).card_id;
    if (!BUILT_IN.includes(figure)) await addFigure(page, id, figure, name);
    const base = BUILT_IN.includes(figure) ? figure : "woman";
    await setSettings(request, { companion: { card_id: id, starts: true, hidden_until: null, figure: base } });

    // The page's clock held (`runFor` moves it) and its chance drawn the same each run: the figure stands still while
    // its points are read and clicked.
    await watchFigure(page);
    await page.addInitScript(() => {
      let seed = 7;
      Math.random = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
    });
    await page.clock.install();
    await page.goto("/companion.html");
    const canvas = page.locator("canvas.companion-figure");
    const state = async () => (await (await request.get("/api/companion/state")).json()).figure;
    await expect(async () => {
      await page.clock.runFor(500);
      expect((await state())?.clip ?? null).not.toBeNull();
    }).toPass({ timeout: 600_000 });
    // It lands from the top of the screen and gets up; then it stands.
    await page.clock.runFor(10_000);
    await canvas.screenshot({ path: `${OUT}/${name}-rest.png` });

    for (const feeling of ["happy", "surprised", "angry", "sad"]) {
      await act(request, [{ do: "react", feeling }]);
      await page.clock.runFor(700);
      await canvas.screenshot({ path: `${OUT}/${name}-${feeling}.png` });
    }

    await act(request, [{ do: "say", text: "Mama made a banana pie, come and see!" }]);
    await expect(page.locator(".companion-say")).toBeVisible();
    const speaking: number[] = [];
    for (let i = 0; i < 10; i++) await page.clock.runFor(200), speaking.push(await mouth(page));
    await page.clock.runFor(12_000);
    await expect(page.locator(".companion-say")).toBeHidden();
    const after = await mouth(page);
    lines.push(`mouth while it speaks: ${speaking.join(" ")}; after: ${after}`);

    if (figure === "robot") lines.push("touch: the robot has no human skeleton");
    else
      for (const part of ["hand", "head"] as const) {
        const text = `Touched ${part}`;
        api.moves([{ do: "say", text }, { do: "react", feeling: "playful" }]);
        const before = api.animated.length;
        const points = await headAndHand(page);
        await page.mouse.click(points[part].x, points[part].y);
        await page.clock.runFor(400);
        await expect.poll(() => api.animated.length, { timeout: 15_000 }).toBe(before + 1);
        const asked = String(api.animated[before]!.body.messages[1].content);
        const told = /The user has just touched the figure's (\w+)\./.exec(asked)?.[1] ?? "nothing";
        await expect(page.locator(".companion-say")).toHaveText(text);
        await page.screenshot({ path: `${OUT}/${name}-touch-${part}.png` });
        await page.clock.runFor(12_000);
        const gone = await page.locator(".companion-say").isHidden();
        lines.push(`${part} (${part === "hand" ? points.bone : "crown"}) clicked: told ${told}, bubble gone after: ${gone}`);
      }
    lines.push(`errors: ${errors.join(" | ") || "none"}`);
    writeFileSync(`${OUT}/${name}.txt`, lines.join("\n") + "\n");
    for (const line of lines) console.log(`${name}: ${line}`);
  });
}
