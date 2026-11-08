// Runs the desktop app for a test: built fresh, on a scratch folder with a
// throwaway database key, and driven through tauri-driver (WebDriver).
//
// It is the only way a test starts the desktop app, on a scratch folder given in `CARDWAVE_DATA_DIR`. `npm
// run test:desktop` needs `tauri-driver` and an `msedgedriver` of the same version as the installed WebView2,
// which updates itself: compare `msedgedriver --version` with `reg query
// "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv`; a
// new driver comes from `https://msedgedriver.microsoft.com/<version>/edgedriver_win64.zip` (check that its
// signature is Microsoft's). Both are in `%USERPROFILE%\.cargo\bin` (`tauri-driver` 2.1.0 came by `cargo
// install tauri-driver --locked`). Nothing may be listening on port 4455.
//
// Node 24 runs the `.ts` files of this folder as they are, but only strips the types: a constructor parameter
// property is refused (seen), as is by Node's documentation an enum; an import names its file with `.ts`. In
// the desktop window the app opens without an address, so on first run (`#/setup`) while its scratch folder
// has no provider; a hidden file field takes a path through WebDriver's "element value"; what tauri-driver is
// started with (environment) reaches the app; tauri-driver passes `ms/cdp/execute` on to WebView2.
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

const root = resolve(import.meta.dirname, "..", "..");
const PORT = 4455;
const NATIVE_PORT = 4456;
const DRIVER = `http://127.0.0.1:${PORT}`;
/** The key WebDriver names an element by. */
const ELEMENT = "element-6066-11e4-a52e-4f735466cecf";

type Element = string;

async function call<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(DRIVER + path, {
    method,
    headers: { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const { value } = (await res.json()) as { value: T & { error?: string; message?: string } };
  if (!res.ok) throw new Error(`${method} ${path}: ${value?.error}: ${value?.message}`);
  return value;
}

/** Asks again until `ask` has an answer; says what was waited for when none comes. */
export async function until<T>(what: string, ask: () => Promise<T | null | undefined | false> | T | null | undefined | false, ms = 15_000): Promise<T> {
  let last: unknown;
  for (const end = Date.now() + ms; Date.now() < end; await sleep(100)) {
    try {
      const answer = await ask();
      if (answer) return answer;
    } catch (error) {
      last = error;
    }
  }
  throw new Error(`waited ${ms} ms for ${what}${last ? `: ${last}` : ""}`);
}

/** The running app: its window, and the scratch folder all of it is kept in. */
export class Desktop {
  readonly scratch: string;
  /** Where the app keeps its database. */
  readonly data: string;
  /** Where the window saves files. */
  readonly downloads: string;
  private readonly driver: ChildProcess;
  private readonly session: string;

  private constructor(scratch: string, driver: ChildProcess, session: string) {
    this.scratch = scratch;
    this.driver = driver;
    this.session = session;
    this.data = join(scratch, "data");
    this.downloads = join(scratch, "downloads");
  }

  /** Builds the UI and the app, and starts the app on a new scratch folder. */
  static async start(): Promise<Desktop> {
    for (const [command, args] of [
      ["npm", ["--prefix", "web", "run", "build"]],
      ["cargo", ["build", "-p", "cardwave-desktop"]],
    ] as const) {
      const built = spawnSync(command, args, { cwd: root, stdio: "inherit", shell: command === "npm" });
      if (built.status !== 0) throw new Error(`${command} ${args.join(" ")} failed`);
    }
    const exe = join(process.env.CARGO_TARGET_DIR ?? join(root, "target"), "debug", "cardwave.exe");
    // A driver left over from a run that was cut short would answer in place of
    // the new one, with that run's folder and key.
    if (await call("GET", "/status").then(() => true, () => false)) {
      throw new Error(`port ${PORT} is in use: end the tauri-driver of an earlier run first`);
    }

    const scratch = join(tmpdir(), `cardwave-desktop-test-${process.pid}`);
    rmSync(scratch, { recursive: true, force: true });
    mkdirSync(join(scratch, "downloads"), { recursive: true });
    // The app takes its folder and key from here, and so never opens the user's
    // own data. Should it ever look there all the same, this key does not fit.
    const env = { ...process.env, CARDWAVE_DATA_DIR: scratch, CARDWAVE_DB_KEY: randomBytes(32).toString("hex"), CARDWAVE_USER: "local" };
    const driver = spawn("tauri-driver", ["--port", String(PORT), "--native-port", String(NATIVE_PORT)], { env, stdio: ["ignore", "inherit", "inherit"] });
    let failed: Error | undefined;
    driver.on("error", (error) => (failed = new Error(`cannot start tauri-driver (is it installed and on PATH?): ${error.message}`)));
    // A run that is cut short takes the driver and the app with it.
    process.once("exit", () => stop(driver, scratch));
    try {
      await until("tauri-driver", async () => {
        if (failed) throw failed;
        return (await call<{ ready: boolean }>("GET", "/status")).ready;
      });
      const capabilities = { alwaysMatch: { browserName: "wry", "tauri:options": { application: exe } } };
      const { sessionId } = await call<{ sessionId: string }>("POST", "/session", { capabilities });
      const desktop = new Desktop(scratch, driver, sessionId);
      // Files are saved without asking, into the scratch folder and not the user's Downloads.
      await desktop.send("POST", "/ms/cdp/execute", {
        cmd: "Browser.setDownloadBehavior",
        params: { behavior: "allow", downloadPath: desktop.downloads },
      });
      return desktop;
    } catch (error) {
      stop(driver, scratch);
      throw error;
    }
  }

  private send<T>(method: string, path: string, body?: unknown): Promise<T> {
    return call<T>(method, `/session/${this.session}${path}`, body);
  }

  /** Closes the app and removes its scratch folder. */
  async close(): Promise<void> {
    await this.send("DELETE", "").catch(() => {});
    stop(this.driver, this.scratch);
  }

  /** The first element that matches, once there is one. */
  find(css: string): Promise<Element> {
    return until(css, async () => (await this.send<Record<string, string>>("POST", "/element", { using: "css selector", value: css }))[ELEMENT]);
  }

  /** The first element of this kind with exactly this text, once there is one. */
  findText(tag: string, text: string): Promise<Element> {
    // XPath has no escapes: a text with a double quote in it is put together from its parts.
    const quoted = text.includes('"') ? `concat(${text.split('"').map((part) => `"${part}"`).join(`, '"', `)})` : `"${text}"`;
    const value = `//${tag}[normalize-space()=${quoted}]`;
    return until(`${tag} “${text}”`, async () => (await this.send<Record<string, string>>("POST", "/element", { using: "xpath", value }))[ELEMENT]);
  }

  text(element: Element): Promise<string> {
    return this.send("GET", `/element/${element}/text`);
  }

  click(element: Element): Promise<void> {
    return this.send("POST", `/element/${element}/click`, {});
  }

  /** Types into a field; a file field takes the file's path. */
  type(element: Element, text: string): Promise<void> {
    return this.send("POST", `/element/${element}/value`, { text });
  }

  /** Moves the mouse onto an element. */
  hover(element: Element): Promise<void> {
    const move = { type: "pointerMove", duration: 0, origin: { [ELEMENT]: element }, x: 0, y: 0 };
    return this.send("POST", "/actions", { actions: [{ type: "pointer", id: "mouse", parameters: { pointerType: "mouse" }, actions: [move] }] });
  }

  /** Presses on an element with a mouse button (0 the left, 2 the right), `times` in a row. */
  press(element: Element, button = 0, times = 1): Promise<void> {
    const move = { type: "pointerMove", duration: 0, origin: { [ELEMENT]: element }, x: 0, y: 0 };
    const clicks = Array.from({ length: times }, () => [{ type: "pointerDown", button }, { type: "pointerUp", button }]).flat();
    return this.send("POST", "/actions", { actions: [{ type: "pointer", id: "mouse", parameters: { pointerType: "mouse" }, actions: [move, ...clicks] }] });
  }

  /** Presses on the middle of an element, moves the mouse by `dx`, `dy` in `steps` steps and lets go. */
  drag(element: Element, dx: number, dy: number, steps = 6): Promise<void> {
    const start = { type: "pointerMove", duration: 0, origin: { [ELEMENT]: element }, x: 0, y: 0 };
    const moves = Array.from({ length: steps }, () => ({ type: "pointerMove", duration: 30, origin: "pointer", x: Math.round(dx / steps), y: Math.round(dy / steps) }));
    const actions = [start, { type: "pointerDown", button: 0 }, ...moves, { type: "pointerUp", button: 0 }];
    return this.send("POST", "/actions", { actions: [{ type: "pointer", id: "mouse", parameters: { pointerType: "mouse" }, actions }] });
  }

  /** The app's windows, by WebDriver's handles. */
  windows(): Promise<string[]> {
    return this.send("GET", "/window/handles");
  }

  /** Drives the window `handle` from now on. */
  switchTo(handle: string): Promise<void> {
    return this.send("POST", "/window", { handle });
  }

  /** Shows another page in the window. */
  go(url: string): Promise<void> {
    return this.send("POST", "/url", { url });
  }

  /** The address of the page in the window. */
  url(): Promise<string> {
    return this.send("GET", "/url");
  }

  /** Runs a script in the page and returns what it returns. */
  run<T>(script: string, ...args: unknown[]): Promise<T> {
    return this.send("POST", "/execute/sync", { script, args });
  }
}

/** Ends tauri-driver with the driver and app it started, then removes the scratch folder. */
function stop(driver: ChildProcess, scratch: string): void {
  if (driver.pid) spawnSync("taskkill", ["/pid", String(driver.pid), "/T", "/F"], { stdio: "ignore" });
  if (existsSync(scratch)) rmSync(scratch, { recursive: true, force: true, maxRetries: 20, retryDelay: 250 });
}
