import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import type { Plugin } from "vite";
import { defineConfig } from "vitest/config";
import { codesMissing, idsMissing, missing } from "./src/language/keys";

/** English's text, its files `en.ftl` and `en.<part>.ftl` in one. */
const english = (folder: string) =>
  readdirSync(folder)
    .filter((file) => /^en(\.[\w-]+)?\.ftl$/.test(file))
    .map((file) => readFileSync(join(folder, file), "utf8"))
    .join("\n");

/**
 * Fails the build, and the dev server's start, on a key of the UI's words that the English file lacks
 * (src/language/keys.ts), or the words of an error code of the server; the language's own modules and the tests
 * are not looked into.
 */
function wordsChecked(): Plugin {
  return {
    name: "cardwave-words",
    buildStart() {
      const root = join(__dirname, "src");
      const files = (readdirSync(root, { recursive: true }) as string[]).filter((file) => file.endsWith(".ts") && !file.endsWith(".test.ts") && !/^language[\\/]/.test(file));
      const words = english(join(root, "language"));
      const wrong = missing(files.map((file) => [file, readFileSync(join(root, file), "utf8")]), words);
      wrong.push(...codesMissing(readFileSync(join(root, "api", "generated", "Code.ts"), "utf8"), words));
      wrong.push(...idsMissing(readFileSync(join(root, "api", "generated", "InterviewTextId.ts"), "utf8"), words));
      if (wrong.length) this.error(`The UI's words (src/language/en.ftl and en.*.ftl):\n${wrong.join("\n")}`);
    },
  };
}

// `npm run dev` proxies the API to a server started with `cargo run -p cardwave-server`.
const server = process.env.CARDWAVE_SERVER ?? "http://127.0.0.1:8477";

export default defineConfig({
  plugins: [wordsChecked()],
  // Two pages: the app, and the desktop app's companion window (src/companion/main.ts), with its 3D model.
  // The companion's script is three.js with it (about 590 kB), read from this computer: no warning for its size.
  build: { rollupOptions: { input: { main: "index.html", companion: "companion.html" } }, chunkSizeWarningLimit: 700 },
  assetsInclude: ["**/*.glb"],
  server: {
    proxy: {
      "/api": server,
      "/ws": { target: server.replace(/^http/, "ws"), ws: true },
    },
  },
  // `npm test`: the tests of the modules' logic, each beside its module, in a page that is no browser's (happy-dom).
  // A rule of a module's logic gets its test there: what a function answers, what a control decides, where the
  // focus goes, what a late or a failed answer changes.
  // Traps of that page: what is set as a property (`ariaLabel`, `ariaPressed`, `ariaExpanded`, as `el` sets
  // them) is no attribute there, so a test reads the property and finds an element by its class, its `role` or
  // its place, not by `[aria-label]`; every element has one client rect, a hidden one too, so what asks whether
  // a thing shows (`getClientRects`) says yes; `getComputedStyle` knows a `<style>` put into the page, and
  // styles.css is not there, so a test of what follows a style puts that one rule into the page (rail.test.ts);
  // the window's width is set with `window.happyDOM.setViewport`, which a `matchMedia` list hears; `focus()`
  // does nothing on what is disabled or out of the page, as in a browser, and `showModal` leaves the focus
  // where it was; what a module listens to on `document` stays there from test to test of a file, so the rail
  // of a test before would close the next one's drawer, and rail.test.ts takes each listener away after its
  // test; what a module keeps while the app runs (account.ts keeps the account) it keeps from test to test too,
  // so its own tests load it anew each time (`vi.resetModules()` and `await import(...)`, account.test.ts) and
  // a test of what uses it puts a stand-in in its place (`vi.mock("./account", ...)`, rail.test.ts; seen: a
  // test's own failing answer was never asked for, and was told as an error nobody caught); `vitest` shows
  // nothing a passing test logs.
  test: { environment: "happy-dom", include: ["src/**/*.test.ts"] },
});
