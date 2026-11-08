// What api/client.ts decides without a server: how an address is written, what a backup's frame says, and how a refusal is worded.
import { expect, test, vi } from "vitest";
import { ApiError, avatarUrl, cardThumbnailUrl, changeCompanion, getChat, saveBackup } from "./client";

test("a chat character's round picture is its card's picture asked for small, and an avatar of its own as it is", () => {
  const of = (avatar_url: string) => avatarUrl({ avatar_url, version_id: 7 });
  expect(of("/api/card-versions/7/image")).toBe("/api/card-versions/7/image?size=96x128");
  expect(of("/api/card-versions/7/image")).toBe(cardThumbnailUrl(7, "row"));
  expect(of("/api/card-versions/7/assets/avatar.png")).toBe("/api/card-versions/7/assets/avatar.png");
  // An asset that happens to be called so is no card's picture.
  expect(of("/api/card-versions/7/assets/image.png")).toBe("/api/card-versions/7/assets/image.png");
  expect(of("/api/card-versions/7/assets/image")).toBe("/api/card-versions/7/assets/image");
  expect(of("")).toBe("");
});

test("the backup's frame says a failure only of a page the server answered, not of its first empty one", () => {
  HTMLFormElement.prototype.submit = () => {};
  const failed = vi.fn();
  saveBackup("harbour lights", failed);
  const frame = document.querySelector<HTMLIFrameElement>("iframe[name=backup]")!;
  // A browser that loads the empty first page late (Firefox) tells it after the handler is set.
  frame.dispatchEvent(new Event("load"));
  expect(failed).not.toHaveBeenCalled();
});

test("a refused request is told in the UI's words for its code, never in the server's sentence", async () => {
  const body = { code: "chat_busy", error: "the server's own sentence", details: {} };
  vi.stubGlobal("fetch", async () => new Response(JSON.stringify(body), { status: 409, headers: { "Content-Type": "application/json" } }));
  const refused = await getChat(7).catch((error) => error);
  vi.unstubAllGlobals();
  expect(refused).toBeInstanceOf(ApiError);
  expect([refused.status, refused.code, refused.message]).toEqual([409, "chat_busy", "A reply is being written in this chat; stop it first."]);
});

test("the backup's frame tells what the server refused in the UI's words", () => {
  HTMLFormElement.prototype.submit = () => {};
  const failed = vi.fn();
  saveBackup(undefined, failed);
  const frame = document.querySelector<HTMLIFrameElement>("iframe[name=backup]")!;
  Object.defineProperty(frame, "contentDocument", { configurable: true, value: { URL: "http://x/api/backup/save", body: { textContent: JSON.stringify({ code: "backup_needs_password", error: "the server's own", details: {} }) } } });
  frame.dispatchEvent(new Event("load"));
  expect(failed).toHaveBeenCalledWith("A backup needs a password.");
});

test("two changes of the companion, sent at once, each keep what the other changed", async () => {
  let stored = { card_id: 3, starts: true, hidden_until: null as string | null, figure: "woman" };
  vi.stubGlobal("fetch", async (_path: string, init: RequestInit) => {
    if (init.method === "PATCH") stored = JSON.parse(init.body as string).companion;
    return new Response(JSON.stringify({ companion: stored }), { headers: { "Content-Type": "application/json" } });
  });
  await Promise.all([changeCompanion({ figure: "robot" }), changeCompanion({ starts: false })]);
  vi.unstubAllGlobals();
  expect(stored).toEqual({ card_id: 3, starts: false, hidden_until: null, figure: "robot" });
});

