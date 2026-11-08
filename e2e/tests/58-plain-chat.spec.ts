import { expect, test } from "../test";
import { picture, stopClock } from "../pictures";

// Chat without a character (board "Chat without a character"): Create's line starts a chat with the AI itself,
// "New chat" until the pretend model (crates/cw-provider/src/pretend.rs) names it after its first reply, which
// stands under the model's name with the robot round; the header has the model's name under the title, the field
// says "Message", the user writes as the account (by its name), the side panel has no persona, prompt preset or
// lorebooks, and "+" no "Add a character"; Settings holds the one text such a chat's AI is told. The picture
// (1440 px, light) is of the chat once named.

/** What the pretend model answers every chat with (`REPLY`), and the title it gives such a chat. */
const REPLY = "This is Cardwave's pretend model. It gives every message this same reply, so the app can be tried without a provider.";
const TITLE = "A talk with the pretend model";

test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
test.beforeEach(({ page }) => stopClock(page));

test("Chat without a character is the AI itself, and the chat names itself after the first reply", async ({ page, request }) => {
  const provider = await request.put("/api/provider", { data: { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" } });
  expect(provider.status(), await provider.text()).toBe(200);
  await page.goto("/#/chats");
  await page.getByRole("group", { name: "New" }).getByRole("button", { name: "Chat without a character" }).click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(page.locator(".chat-bar h1 .chat-who > span").first()).toHaveText("New chat");
  await expect(page.locator(".chat-bar h1 .meta")).toHaveText("pretend-chat");
  const composer = page.getByLabel("Message", { exact: true });
  await expect(composer).toHaveAttribute("placeholder", "Message");
  await expect(page.getByLabel("Persona", { exact: true })).toBeHidden();
  await expect(page.getByLabel("Prompt preset", { exact: true })).toBeHidden();
  await expect(page.getByRole("heading", { name: "Lorebooks" })).toBeHidden();
  await page.getByRole("button", { name: "Attach, or let the AI write" }).click();
  // Write for me, Improve and Make a picture need a character: not there, rather than grey with no reason.
  await expect(page.getByRole("menuitem", { name: "Attach picture or document" })).toBeVisible();
  await expect(page.getByRole("menuitem", { name: "Write for me" })).toBeHidden();
  await expect(page.getByRole("menuitem", { name: "Improve my message" })).toBeHidden();
  await expect(page.getByRole("menuitem", { name: "Make a picture" })).toBeHidden();
  await expect(page.getByRole("menuitem", { name: "Add a character" })).toBeHidden();
  await page.keyboard.press("Escape");

  await composer.fill("Plan a weekend in Lisbon.");
  await composer.press("Enter");
  await expect(page.locator(".message").first().locator(".speaker")).toHaveText("local");
  const reply = page.locator(".message").last();
  await expect(reply.locator(".text")).toHaveText(REPLY);
  await expect(reply.locator(".speaker")).toHaveText("AI");
  await expect(reply.locator(".avatar.ai svg")).toBeVisible();
  await expect(page.locator(".chat-bar h1 .chat-who > span").first()).toHaveText(TITLE);
  await expect(page.locator("#rail").getByRole("link", { name: TITLE })).toBeVisible();
  await picture(page, "plain-chat-1440-light");
});

test("Settings › Advanced holds the one text a chat without a character's AI is told, saved on leaving it", async ({ page, request }) => {
  await page.goto("/#/settings/advanced");
  const told = page.getByRole("textbox", { name: "What the AI is told", exact: true });
  await expect(told).toHaveValue("You are a helpful, honest assistant. It is now {{date}}, {{time}}.");
  await told.fill("You are terse. It is {{date}}.");
  await told.blur();
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).plain_prompt).toBe("You are terse. It is {{date}}.");
  await page.reload();
  await expect(told).toHaveValue("You are terse. It is {{date}}.");

  // A second change left while the first is on its way is saved after it.
  let release = () => {};
  const held = new Promise<void>((done) => (release = done));
  await page.route("**/api/settings", async (route) => {
    if (route.request().method() === "PATCH") await held;
    await route.fallback();
  });
  await told.fill("First.");
  await told.blur();
  await told.fill("Second.");
  await told.blur();
  release();
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).plain_prompt).toBe("Second.");
});

test("at 600 px a chat's messages stand 16 px from the sides and 20 px under the bar (board NarrowChat)", async ({ page, request }) => {
  await page.setViewportSize({ width: 600, height: 900 });
  const chat = await request.post("/api/chats", { data: { characters: [] } });
  expect(chat.status(), await chat.text()).toBe(201);
  await page.goto(`/#/chats/${(await chat.json()).chat.id}`);
  const scroller = page.locator(".chat-scroller");
  await expect(scroller).toHaveCSS("padding-left", "16px");
  await expect(scroller).toHaveCSS("padding-top", "20px");
});
