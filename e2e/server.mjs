// What the browser tests run on. The default export is Playwright's global setup: it builds the web UI and the
// server, once for the run; with `E2E_SERVER` (a built server program's path, such as `main`'s from a worktree) it
// builds the UI alone and runs that program. `serve` starts the real server for one spec file, on a data folder of its own that is
// empty (test.ts asks for it), and starts it again on that folder with its key when a spec asks (`restart`). The run's workers each have a port of their own, from `E2E_PORT` on.
//
// As the setup (`globalSetup` in playwright.config.ts) it says nothing unless a build fails, and stops the
// servers a killed run left: `sweep` stops the process a folder's `server.pid` names only if that was started
// on that folder (`isServerOf`), and removes the folders too; Windows refuses the folder of a server just
// stopped for a moment, and `rmSync` does not try again by itself, so `remove` does. A server ends with the
// Node that started it on Windows, so a killed run mostly leaves folders only, and one who tries `sweep` by
// hand starts the server `detached` (seen). One run at a time in this folder: a second one ends at once and
// says that the ports are taken (`alone`). The stand-in for the providers' hosts has the port 100 above its
// worker's server's (`CARDWAVE_PROVIDER_PLACES`), the stand-in for the search model 300 above
// (`CARDWAVE_EMBEDDER`), which serves `searchModel` as the model's download (`CARDWAVE_SEARCH_MODEL`), as the
// voice's (`CARDWAVE_VOICE_MODEL`, which a tone then speaks for), as dictation's (`CARDWAVE_DICTATION_MODEL`, which then hears `HEARD` in every recording: `CARDWAVE_DICTATION_HEARS`) and as This computer's "Test model" (`CARDWAVE_LOCAL_MODELS`). The folder first run offers is the server's own `Documents` (`CARDWAVE_DOCUMENTS`), empty. Its listener of the home network listens on this computer alone (`CARDWAVE_NETWORK_LOOPBACK`).
import { spawn, spawnSync } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
/** The first of the run's ports. A second run beside this one is given another. */
const PORT = Number(process.env.E2E_PORT ?? 8490);
/** Where the run's servers keep their data, each in a folder of its own. */
const scratch = join(tmpdir(), `cardwave-e2e-${PORT}`);
const PROGRAM = process.platform === "win32" ? "cardwave-server.exe" : "cardwave-server";
/** The server program the run starts: `E2E_SERVER`'s, which is not built, else this folder's debug build. */
const given = process.env.E2E_SERVER;
const exe = given ? resolve(given) : join(process.env.CARGO_TARGET_DIR ?? join(root, "target"), "debug", PROGRAM);
/** How long a server may take to say that it listens, in milliseconds. */
const START_WAIT = 30_000;
/** Where the server of the data folder `folder` keeps its database: what it is started with, and known by. */
const dataOf = (folder) => join(folder, "data");

/**
 * The ports of the run's worker number `worker` (from 0): its server's, the one its server looks for a
 * provider's API on (`startFakePlaces` in fake-provider.ts), 100 above, and its search model's
 * (`startFakeSearch` in fake-search.ts), 300 above (200 above is the run's own, `alone`).
 */
export const ports = (worker) => ({ server: PORT + worker, places: PORT + 100 + worker, search: PORT + 300 + worker });

/** The file the search model's stand-in serves as its download: 20 pieces of 16 KB. */
/** What dictation's stand-in hears in every recording. */
export const HEARD = "Hello from the microphone.";
export const searchModel = () => Buffer.concat(Array.from({ length: 20 }, (_, n) => Buffer.alloc(16 * 1024, n)));

/**
 * Removes a folder a server kept its data in. Windows gives the files of a server that was stopped free a moment
 * after it (seen: 0.1 s, and `rmSync` does not try again by itself where the folder is refused), so it tries for 5 s.
 */
function remove(folder) {
  for (let tries = 50; ; tries--) {
    try {
      return rmSync(folder, { recursive: true, force: true });
    } catch (error) {
      if (tries === 0) throw error;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
    }
  }
}

/**
 * Whether the process `pid` is the server that was started on `folder`, by what it was started with. A number kept
 * from a run long gone may be another program's by now, or the server of another run.
 */
function isServerOf(pid, folder) {
  if (!Number.isInteger(pid)) return false;
  const asked =
    process.platform === "win32"
      ? spawnSync("powershell", ["-NoProfile", "-Command", `(Get-CimInstance Win32_Process -Filter 'ProcessId = ${pid}').CommandLine`])
      : spawnSync("ps", ["-p", String(pid), "-o", "args="]);
  return String(asked.stdout).includes(dataOf(folder));
}

/**
 * Stops the servers a run left behind and removes their folders. A worker stops its own server; one that was
 * killed could not, and a database that is open keeps its folder from being removed.
 */
function sweep() {
  if (!existsSync(scratch)) return;
  for (const folder of readdirSync(scratch)) {
    try {
      const pid = Number(readFileSync(join(scratch, folder, "server.pid"), "utf8"));
      if (isServerOf(pid, join(scratch, folder))) process.kill(pid);
    } catch {
      // It wrote no number, or is gone.
    }
  }
  remove(scratch);
}

/**
 * Says that this run has the ports from `PORT` on, by listening on one more, 200 above, until the run ends. A second
 * run with the same ports ends here: its `sweep` would take the first run's servers for ones left behind.
 */
export async function alone() {
  const held = createServer();
  await new Promise((free, taken) => {
    held.once("error", () => taken(new Error(`another run of the browser tests has the ports from ${PORT} on: wait for it, or give this one others (E2E_PORT)`)));
    held.listen(PORT + 200, "127.0.0.1", free);
  });
  // It ends with the run, and does not keep the run from ending.
  held.unref();
}

/**
 * Builds the web UI and the server (the UI alone where `E2E_SERVER` gives the program), and answers with what is
 * done when the run is over. Says nothing unless a build fails.
 */
export default async function build() {
  await alone();
  sweep();
  if (given && !existsSync(exe)) throw new Error(`E2E_SERVER names no program: ${exe}`);
  const builds = ["npm --prefix web run build", ...(given ? [] : ["cargo build -p cardwave-server"])];
  for (const command of builds) {
    const built = spawnSync(command, { cwd: root, shell: true, encoding: "utf8", maxBuffer: 1 << 28 });
    if (built.status !== 0) throw new Error(`${command} failed:\n${`${built.stdout}${built.stderr}`.trim().split("\n").slice(-60).join("\n")}`);
  }
  return sweep;
}

/**
 * Starts the server for the worker number `worker` on a data folder that is new, and answers once it listens: with
 * its address, with `stop`, which ends it and removes the folder, and with `restart`, which ends it and starts it
 * again on the same folder with the same key, as when the app is closed and opened.
 */
export async function serve(worker) {
  const { server: port, places, search } = ports(worker);
  const model = searchModel();
  const sum = createHash("sha256").update(model).digest("hex");
  mkdirSync(scratch, { recursive: true });
  const folder = mkdtempSync(join(scratch, `${worker}-`));
  const documents = join(folder, "Documents");
  mkdirSync(documents);
  // A throwaway key, so test runs leave nothing in the credential store.
  const key = randomBytes(32).toString("hex");

  /** Starts the program on the folder, and answers how it is ended once it listens. */
  async function launch() {
    // The program itself, not `cargo run`: killing cargo would leave the server running on Windows.
    const server = spawn(exe, ["--port", String(port), "--data-dir", dataOf(folder), "--web-dir", "web/dist"], {
      cwd: root,
      stdio: ["ignore", "pipe", "pipe"],
      // The search for a provider's API asks the specs' own stand-in, never a provider, and the search model is
      // theirs, never bge-m3.
      env: {
        ...process.env,
        CARDWAVE_DB_KEY: key,
        CARDWAVE_NO_FACES: '1',
        CARDWAVE_PROVIDER_PLACES: `http://127.0.0.1:${places}`,
        CARDWAVE_SEARCH_MODEL: `http://127.0.0.1:${search}/model.gguf ${model.length} ${sum}`,
        CARDWAVE_EMBEDDER: `http://127.0.0.1:${search}`,
        CARDWAVE_VOICE_MODEL: `http://127.0.0.1:${search}/model.gguf ${model.length} ${sum}`,
        CARDWAVE_DICTATION_MODEL: `http://127.0.0.1:${search}/model.gguf ${model.length} ${sum}`,
        CARDWAVE_DICTATION_HEARS: HEARD,
        CARDWAVE_LOCAL_MODELS: `http://127.0.0.1:${search}/model.gguf ${model.length} ${sum}`,
        // The home network's listener on this computer alone, as Windows asks before a program listens on the network.
        CARDWAVE_NETWORK_LOOPBACK: "1",
        // The folder first run offers in place of the user's Documents, which no test may import.
        CARDWAVE_DOCUMENTS: documents,
        // This computer's account's first name in place of the system's user name, which no test may show.
        CARDWAVE_USER: "local",
      },
    });
    const gone = new Promise((exited) => server.once("exit", exited).once("error", exited));
    if (server.pid) writeFileSync(join(folder, "server.pid"), String(server.pid));
    const end = async () => {
      server.kill();
      await gone;
    };

    // It says where it runs once it listens. What it says after that is read and dropped, so that it never waits to be read.
    let said = "";
    const listening = new Promise((heard) => {
      for (const stream of [server.stdout, server.stderr]) {
        stream.on("data", (part) => {
          said = (said + part).slice(-4000);
          if (said.includes("Cardwave running at")) heard(true);
        });
      }
    });
    const timer = new Promise((late) => setTimeout(late, START_WAIT, false).unref());
    if ((await Promise.race([listening, gone.then(() => false), timer])) !== true) {
      await end();
      remove(folder);
      throw new Error(`the server did not start on port ${port} (one that a killed run left may still listen there):\n${said.trim()}`);
    }
    return end;
  }

  let end = await launch();
  const stop = async () => {
    await end();
    remove(folder);
  };
  const restart = async () => {
    await end();
    end = await launch();
  };
  return { url: `http://127.0.0.1:${port}`, stop, restart };
}
