// The companion window, which only the desktop app has: "Make companion" in a card's menu opens it, see-through,
// always on top and letting clicks through where the cursor is not on its figure (Windows' own word for the window,
// asked by `windowStyle`); a double-click on the figure opens the compact chat, whose "Open in Cardwave" shows the
// chat in the app's window, and the menu's "Close companion" closes it; the settings' line "Companion" opens and
// closes it too, and so does "Lock" in the account's menu while a password is on. At the smallest and largest
// size (Settings) the figure is dragged, lands on the floor and walks. Run with `npm run test:desktop`.
//
// Each window is driven by WebDriver's handle of it (`switchTo`). A press of WebDriver goes to the page itself and
// not through Windows, so it reaches the figure whether or not the window lets clicks through. Whether the window
// lets clicks through hangs on where the real cursor is (over the figure it takes them), so the check puts the
// cursor in the screen's top left corner, away from the figure, and back where it was after (`away`).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { after, before, test } from "node:test";
import { Desktop, until } from "./driver.ts";

let app: Desktop;

before(async () => {
  app = await Desktop.start();
});
after(() => app?.close());

/** Puts the screen's cursor at `x`, `y` and answers where it was. */
function cursorAt(x: number, y: number): { x: number; y: number } {
  const script = `Add-Type -AssemblyName System.Windows.Forms; $p = [System.Windows.Forms.Cursor]::Position; [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(${x}, ${y}); "$($p.X) $($p.Y)"`;
  const asked = spawnSync("powershell", ["-NoProfile", "-Command", script], { encoding: "utf8" });
  assert.equal(asked.status, 0, `the cursor was not moved: ${asked.stderr}`);
  const [was, wasY] = asked.stdout.trim().split(" ").map(Number);
  return { x: was!, y: wasY! };
}

/** Runs `check` with the cursor in the screen's top left corner, away from the figure, and puts it back after. */
async function away<T>(check: () => Promise<T>): Promise<T> {
  const was = cursorAt(0, 0);
  try {
    return await check();
  } finally {
    cursorAt(was.x, was.y);
  }
}

/** The settings' switch "Companion", once it can be pressed; found anew each time, as a change of the settings draws it anew. */
function companionSwitch(): Promise<string> {
  return until("the switch ready", async () => {
    const toggle = await app.find('input[role="switch"][aria-label="Companion"]');
    return (await app.run<boolean>("return !arguments[0].disabled", { "element-6066-11e4-a52e-4f735466cecf": toggle })) && toggle;
  });
}

/** WS_EX_TOPMOST and WS_EX_TRANSPARENT of the window of this title: on top, and letting clicks through. */
function windowStyle(title: string): { top: boolean; through: boolean } {
  const script = `
Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern System.IntPtr FindWindow(string c, string t); [DllImport("user32.dll")] public static extern System.IntPtr GetWindowLongPtr(System.IntPtr h, int i);'
$h = [W.U]::FindWindow([NullString]::Value, '${title}')
if ($h -eq [System.IntPtr]::Zero) { exit 3 }
[W.U]::GetWindowLongPtr($h, -20).ToInt64()`;
  const asked = spawnSync("powershell", ["-NoProfile", "-Command", script], { encoding: "utf8" });
  assert.equal(asked.status, 0, `no window “${title}”: ${asked.stderr}`);
  const style = Number(asked.stdout.trim());
  return { top: (style & 0x8) !== 0, through: (style & 0x20) !== 0 };
}

test("“Make companion” opens the companion on top of everything, whose compact chat opens in the app, and “Close companion” closes it", async () => {
  const [main] = await app.windows();
  // The window may still be loading the app's page, where a fetch has no address to go from.
  await until("the app's page", async () => (await app.url()).startsWith("http"));
  const id = await app.run<number>(`return fetch("/api/cards/new", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ title: "Gwen", tags: [], creator: "", name: "Gwen", greetings: ["Hello."], description: "", personality: "", scenario: "", example_dialogue: "", creator_notes: "" }) }).then((made) => made.json()).then((made) => made.card_id)`);
  await app.go(`${new URL(await app.url()).origin}/#/library/${id}`);
  await app.click(await app.find('button[aria-label="Character menu"]'));
  await app.click(await app.findText("button", "Make companion"));
  const companion = await until("the companion's window", async () => (await app.windows()).find((handle) => handle !== main));
  await away(() =>
    until("the companion's window on top, letting clicks through", () => {
      const { top, through } = windowStyle("Cardwave companion");
      return top && through;
    }),
  );

  await app.switchTo(companion);
  const figure = await app.find("canvas.companion-figure");
  await app.press(figure, 0, 2);
  await app.findText("span", "Gwen");
  await app.click(await app.find('button[aria-label="Open in Cardwave"]'));
  await app.switchTo(main!);
  await until("the chat in the app's window", async () => /#\/chats\/\d+$/.test(await app.url()));

  await app.switchTo(companion);
  await app.press(figure, 2);
  await app.click(await app.findText("button", "Close companion"));
  await until("the companion's window closed", async () => (await app.windows()).length === 1);

  // The settings' line, still on: off, then on opens the window anew, letting clicks through again; off closes it.
  await app.switchTo(main!);
  await app.go(`${new URL(await app.url()).origin}/#/settings`);
  await app.findText("span", "Gwen · Starts with the app");
  const toggle = await app.find('input[role="switch"][aria-label="Companion"]');
  const turned = (on: boolean) => until(`the switch ${on ? "on" : "off"}`, () => app.run<boolean>(`const t = arguments[0]; return !t.disabled && t.checked === arguments[1]`, { "element-6066-11e4-a52e-4f735466cecf": toggle }, on));
  await turned(true);
  await app.click(toggle);
  await turned(false);
  await app.click(toggle);
  await until("the companion's window anew", async () => (await app.windows()).length === 2);
  await away(() => until("the new window letting clicks through", () => windowStyle("Cardwave companion").through));
  await turned(true);
  await app.click(toggle);
  await until("the companion's window closed by the switch", async () => (await app.windows()).length === 1);
});

test("at the smallest and largest size the figure is dragged, lands on the floor and walks", async () => {
  const [main] = await app.windows();
  await app.go(`${new URL(await app.url()).origin}/#/settings`);
  await app.click(await companionSwitch());
  const companion = await until("the companion's window", async () => (await app.windows()).find((handle) => handle !== main));
  type Seen = { width: number; height: number; x: number; y: number; state: string; acted: number };
  const seen = () => app.run<Seen>(`return fetch("/api/companion/state").then((answer) => answer.json()).then((state) => state.figure)`);
  const standing = (what: string, test: (figure: Seen) => boolean) =>
    until(what, async () => {
      const figure = await seen();
      return figure && figure.y === figure.height && ["idle", "listening"].includes(figure.state) && test(figure) && figure;
    });

  for (const size of [10, 50]) {
    await app.switchTo(main!);
    // The settings take the companion whole, so the size goes in with the rest of it.
    const set = `return fetch("/api/settings").then((answer) => answer.json()).then(({ companion }) => fetch("/api/settings", { method: "PATCH", headers: { "content-type": "application/json" }, body: JSON.stringify({ companion: { ...companion, size: ${size} } }) })).then((answer) => answer.status)`;
    assert.equal(await app.run<number>(set), 200);
    await app.switchTo(companion);
    const figure = await app.find("canvas.companion-figure");
    await until(`the figure at ${size}%`, async () => Math.round(await app.run<number>("return arguments[0].getBoundingClientRect().height * 0.62 * 100 / innerHeight", { "element-6066-11e4-a52e-4f735466cecf": figure })) === size);
    const before = await standing(`the figure standing at ${size}%`, () => true);

    await app.drag(figure, -150, -150);
    const landed = await standing(`the figure landed after the drag at ${size}%`, (now) => now.x !== before.x);

    const x = Math.round(landed.x > landed.width / 2 ? landed.width / 3 : (landed.width * 2) / 3);
    const act = `return fetch("/api/companion/act", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ steps: [{ do: "walk", x: ${x} }] }) }).then((answer) => answer.status)`;
    assert.equal(await app.run<number>(act), 200);
    await standing(`the figure walked to ${x} at ${size}%`, (now) => Math.abs(now.x - x) <= 1);
  }

  await app.switchTo(main!);
  await app.click(await companionSwitch());
  await until("the companion's window closed by the switch", async () => (await app.windows()).length === 1);
});

test("“Lock” closes the companion and shows the start screen", async () => {
  const [main] = await app.windows();
  await app.go(`${new URL(await app.url()).origin}/#/settings`);
  await app.click(await companionSwitch());
  await until("the companion's window", async () => (await app.windows()).length === 2);
  const on = `return fetch("/api/password", { method: "PUT", headers: { "content-type": "application/json" }, body: JSON.stringify({ password: "harbour lights" }) }).then((answer) => answer.status)`;
  assert.equal(await app.run<number>(on), 200);
  await app.run("location.reload()");
  await app.switchTo(main!);
  await app.click(await app.find("#rail button.account"));
  await app.click(await app.findText("button", "Lock"));
  await until("the companion's window closed by Lock", async () => (await app.windows()).length === 1);
  await app.findText("button", "Open");
});
