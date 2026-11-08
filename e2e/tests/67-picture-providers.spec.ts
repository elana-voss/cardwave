import { createServer, type Server } from "node:http";
import type { AddressInfo } from "node:net";
import { readFileSync } from "node:fs";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider, setImages } from "../stored";

// Settings › Providers with a ComfyUI: its box has the indented line "Workflow", whose field offers ComfyUI's
// default workflow and the ones saved in it; picking one has the background model find where the words go
// (the line says "Testing the workflow…" meanwhile), then says "Pictures by “name”.", and the default one
// is picked back the same way. How a workflow is read and a picture made by it is server/tests/comfy.rs's.
//
// `comfyui` is a stand-in ComfyUI answering by path with the server tests' saved workflow and nodes
// (server/tests/comfy/); `api` is the chat provider, so the background model, which names the first field.

const FIXTURES = new URL("../../server/tests/comfy/", import.meta.url);
const fixture = (name: string) => readFileSync(new URL(name, FIXTURES), "utf8");

let api: FakeProvider;
let comfyui: Server;
let comfyUrl: string;

test.beforeAll(async () => {
  api = await startFakeProvider();
  api.models(["tide-1"]);
  const saved = fixture("saved.json");
  const info = fixture("object_info.json");
  const answers: Record<string, string> = {
    "/system_stats": JSON.stringify({ system: {}, devices: [] }),
    "/models/checkpoints": JSON.stringify(["model.safetensors"]),
    "/userdata": JSON.stringify(["Cardwave.json", "notes.txt"]),
    "/userdata/workflows%2FCardwave.json": saved,
    "/object_info": info,
  };
  comfyui = createServer((request, response) => {
    const body = answers[request.url!.split("?")[0]];
    response.writeHead(body === undefined ? 404 : 200, { "content-type": "application/json" });
    response.end(body ?? "{}");
  });
  await new Promise<void>((done) => comfyui.listen(0, "127.0.0.1", done));
  comfyUrl = `http://127.0.0.1:${(comfyui.address() as AddressInfo).port}`;
});
test.afterAll(() => Promise.all([api.close(), new Promise((done) => { comfyui.closeAllConnections(); comfyui.close(done); })]));

test("a ComfyUI's pictures are made by a workflow saved in it, picked on its box", async ({ page, request }) => {
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "sk-chat" })).status()).toBe(200);
  const images = await setImages(request, { base_url: comfyUrl, model: "model.safetensors" });
  expect(images.status(), await images.text()).toBe(200);
  await page.goto("/#/settings/providers");
  await expect(page.locator(".group.provider")).toHaveCount(2);

  const line = page.locator(".group.provider").nth(1).locator(".item.workflow");
  const field = line.getByLabel("Workflow");
  await expect(line).toContainText("From the workflows ComfyUI holds");
  await expect(field).toHaveText("ComfyUI's default");
  await field.click();
  await expect(page.getByRole("menuitemradio")).toHaveText(["ComfyUI's default", "Cardwave"]);
  await page.keyboard.press("Escape");
  // The chat's provider has no such line.
  await expect(page.locator(".group.provider").nth(0).locator(".item.workflow")).toHaveCount(0);

  api.next(['{"place": 1}']);
  // A list still loading under load draws the page anew and drops the open menu (seen once in the whole run): open it again.
  await expect(async () => {
    await field.click();
    await page.getByRole("menuitemradio", { name: "Cardwave" }).click({ timeout: 2000 });
  }).toPass();
  await expect(page.getByText("Pictures by “Cardwave”.")).toBeVisible();
  await expect(field).toHaveText("Cardwave");
  expect(api.asked.at(-1)!.body.messages.at(-1).content).toContain("CLIPTextEncode “Positive”, text");
  expect((await (await request.get("/api/provider-list")).json()).providers[1].workflow).toBe("Cardwave.json");

  // The page read anew on the server's word of the change can draw the box again under an open menu (seen in
  // the whole run): the menu is opened again until the line is picked.
  await expect(async () => {
    await page.keyboard.press("Escape");
    await field.click();
    await page.getByRole("menuitemradio", { name: "ComfyUI's default" }).click({ timeout: 2000 });
  }).toPass();
  await expect(page.getByText("Pictures by ComfyUI's default workflow.")).toBeVisible();
  await expect(field).toHaveText("ComfyUI's default");
  expect((await (await request.get("/api/provider-list")).json()).providers[1].workflow).toBeNull();
});
