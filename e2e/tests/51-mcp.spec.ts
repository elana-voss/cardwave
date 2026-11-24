import { expect, pickFrom, test } from "../test";

// Account › Server's group "Other programs": the MCP server switched on through its dialog, its address copied,
// the account it serves, and a program that connected (a `request` that lists the tools as one) removed.

test("other programs are served once switched on, as the account chosen, and a program is removed", async ({ page, context, request, baseURL }) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  const added = await request.post("/api/accounts", { data: { name: "Ada", password: "lantern" } });
  expect(added.status(), await added.text()).toBe(201);
  await page.goto("/#/account/server");
  const group = page.locator(".settings-group", { has: page.getByRole("heading", { name: "Other programs" }) });
  await group.getByRole("switch", { name: "Let AI apps on this computer use Cardwave" }).click();
  const dialog = page.getByRole("dialog", { name: "Let AI apps on this computer use Cardwave" });
  await dialog.getByRole("button", { name: "Switch on" }).click();
  await expect(group.getByRole("switch")).toBeChecked();

  const address = `${baseURL}/api/mcp`;
  await expect(group.getByText(address)).toBeVisible();
  await group.getByRole("button", { name: "Copy the MCP address" }).click();
  await expect(page.locator("#toast span")).toHaveText("Address copied.");
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(address);

  await pickFrom(group.getByLabel("As account"), "Ada");
  await expect.poll(async () => (await (await request.get("/api/mcp/settings")).json()).account).toBe((await added.json()).id);

  // A program's request as MCP 2026-07-28 has it: its name in the request's `_meta`, mirrored by headers.
  const _meta = {
    "io.modelcontextprotocol/protocolVersion": "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities": {},
    "io.modelcontextprotocol/clientInfo": { name: "Claude Desktop", version: "1" },
  };
  const list = () =>
    request.post("/api/mcp", {
      headers: { accept: "application/json, text/event-stream", "mcp-protocol-version": "2026-07-28", "mcp-method": "tools/list" },
      data: { jsonrpc: "2.0", id: 0, method: "tools/list", params: { _meta } },
    });
  const connected = await (await list()).json();
  expect(connected.result, JSON.stringify(connected)).toBeDefined();
  await page.reload();
  await group.getByRole("button", { name: "Remove Claude Desktop" }).click();
  await expect(page.locator("#toast span")).toHaveText("“Claude Desktop” removed.");
  await expect(group.getByText("Claude Desktop", { exact: true })).toHaveCount(0);
  const refused = await (await list()).json();
  expect(refused.error?.message).toContain("was removed");
});
