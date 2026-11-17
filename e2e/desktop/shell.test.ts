// The desktop shell on Linux, what the system does for the app: a web link opens in the browser (`xdg-open`),
// "About Cardwave"'s button opens the logs' folder (`xdg-open` too), the folder picker (GTK's) answers the folder
// chosen, and a second start of the app brings up its window instead of opening another. Run under Xvfb and a
// D-Bus session (the single instance asks the session bus): `dbus-run-session -- xvfb-run -a npm run test:desktop`.
// Windows' own of these were tried by hand and run through the installer test; this file skips there.
//
// Traps: a stand-in `xdg-open` first on PATH writes what it was asked to open into the scratch folder, so no
// browser or file manager starts; the commands are asked as the page's buttons ask them
// (`__TAURI_INTERNALS__.invoke`), their answer kept on `window` since WebDriver's script here waits for none; the
// second start runs without `CARDWAVE_DATA_DIR` (only then is the app a single instance), on a HOME of its own.
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, test } from "node:test";
import { setTimeout as sleep } from "node:timers/promises";
import { Desktop, debugProgram, until } from "./driver.ts";
import { xWindows } from "./screen.ts";

const skip = process.platform === "win32" && "Linux's shell; Windows' is tried through the installer test";
let app: Desktop;
let opened: string;

before(async () => {
  if (skip) return;
  const bin = join(process.env.TMPDIR ?? "/tmp", `cardwave-shell-bin-${process.pid}`);
  mkdirSync(bin, { recursive: true });
  opened = join(bin, "opened.txt");
  writeFileSync(join(bin, "xdg-open"), `#!/bin/sh\necho "$1" >> "${opened}"\n`);
  chmodSync(join(bin, "xdg-open"), 0o755);
  process.env.PATH = `${bin}:${process.env.PATH}`;
  app = await Desktop.start();
});
after(() => app?.close());

/** Asks the app's program for `command` as the page does; its answer lands in `window.asked`. */
async function ask(command: string, args: Record<string, unknown> = {}): Promise<void> {
  await app.appPage();
  await app.run("window.asked = undefined; window.__TAURI_INTERNALS__.invoke(arguments[0], arguments[1]).then((answer) => (window.asked = { answer }), (error) => (window.asked = { error: String(error) }))", command, args);
}

/** The answer of the last `ask`, once there is one. */
const answer = () => until("the program's answer", () => app.run<{ answer?: unknown; error?: string } | null>("return window.asked ?? null"), 30_000);

/** What the stand-in xdg-open was asked to open, once it was asked `count` times. */
const openedLines = (count: number) => until(`xdg-open asked ${count} times`, () => existsSync(opened) && readFileSync(opened, "utf8").trim().split("\n").length >= count && readFileSync(opened, "utf8").trim().split("\n"));

test("a web link the page opens goes to the system's browser by xdg-open, not into the window", { skip }, async () => {
  const windows = (await app.windows()).length;
  // Clicked, as the user does: WebKitGTK refuses a `window.open` of a script no click started.
  await app.appPage();
  await app.run("const a = document.createElement('a'); a.id = 'outside'; a.href = 'https://example.com/cardwave'; a.target = '_blank'; a.textContent = 'outside'; a.style.cssText = 'position:fixed;left:300px;top:300px;z-index:99999'; document.body.append(a)");
  await app.click(await app.find("#outside"));
  assert.deepEqual(await openedLines(1), ["https://example.com/cardwave"]);
  assert.equal((await app.windows()).length, windows);
});

test("“About Cardwave”'s button opens the logs' folder by xdg-open", { skip }, async () => {
  await ask("open_logs");
  assert.deepEqual(await answer(), { answer: null });
  const logs = await app.run<string>("return window.cardwaveDesktop.logs");
  assert.equal((await openedLines(2)).at(-1), logs);
});

test("the folder picker (GTK's) answers the folder chosen in it", { skip }, async () => {
  const folder = join(app.scratch, "chosen");
  mkdirSync(folder, { recursive: true });
  await ask("pick_folder", { start: app.scratch });
  // GTK's chooser, at the scratch folder: its location typed, then taken.
  const [picker] = await until("GTK's folder picker", () => xWindows("Select Folder|Open Folder|Select a folder").at(0) && xWindows("Select Folder|Open Folder|Select a folder"));
  spawnSync("xdotool", ["windowfocus", "--sync", picker!]);
  spawnSync("xdotool", ["key", "ctrl+l"]);
  spawnSync("xdotool", ["type", "--delay", "20", `${folder}/`]);
  await sleep(300);
  spawnSync("xdotool", ["key", "Return"]);
  await sleep(300);
  spawnSync("xdotool", ["key", "Return"]);
  const { answer: chosen, error } = await answer();
  assert.equal(error, undefined);
  assert.equal(chosen, folder);
});

test("a second start of the app brings up its window and opens no other", { skip }, async () => {
  const home = join(app.scratch, "home");
  mkdirSync(home, { recursive: true });
  const exe = debugProgram();
  const env = { ...process.env, HOME: home, XDG_DATA_HOME: join(home, "data"), CARDWAVE_DB_KEY: "ab".repeat(32), CARDWAVE_DATA_DIR: undefined };
  const first = spawn(exe, [], { env, stdio: "ignore" });
  try {
    await until("the first start's window", () => xWindows("Cardwave").length === 2, 60_000);
    const second = spawnSync(exe, [], { env, timeout: 30_000 });
    assert.equal(second.status, 0, `the second start did not end by itself: ${second.signal ?? second.status}`);
    await sleep(1000);
    assert.equal(xWindows("Cardwave").length, 2, "the test's window and the first start's, no third");
  } finally {
    first.kill("SIGKILL");
  }
});
