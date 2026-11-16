// The stylesheets read as text: every spacing helper `g-N` the code uses has a rule, and the parts moved out of
// app.css keep the cascade's order. How a rule looks is guarded by the stored pictures alone (CLAUDE.md).
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, test } from "vitest";

const read = (p: string) => readFileSync(join(__dirname, p), "utf8");
const app = [read("app.css"), ...readdirSync(join(__dirname, "app")).filter((f) => f.endsWith(".css")).map((f) => read(`app/${f}`))].join("\n");
const all = read("cardwave.css") + "\n" + app;

function sources(dir: string): string[] {
  return readdirSync(join(__dirname, dir), { withFileTypes: true }).flatMap((d) => (d.isDirectory() ? sources(`${dir}/${d.name}`) : d.name.endsWith(".ts") && !d.name.endsWith(".test.ts") ? [read(`${dir}/${d.name}`)] : []));
}

describe("stylesheets", () => {
  test("every g-N helper the code uses is defined", () => {
    const used = new Set(sources("").concat(...["views", "card", "chat", "library", "lorebook", "models", "settings", "setup", "shell", "voice", "companion", "figures", "interview"].map((d) => { try { return sources(d); } catch { return []; } })).flatMap((s) => [...s.matchAll(/\bg-(\d+)\b/g)].map((m) => m[1])));
    const missing = [...used].filter((n) => !new RegExp(`\\.g-${n}\\b`).test(all));
    expect(missing).toEqual([]);
  });
  test("the files moved out of app.css keep the cascade's order", () => {
    const order = [...read("styles.css").matchAll(/@import "\.\/([^"]+)"/g)].map((m) => m[1]);
    const at = (f: string) => order.indexOf(f);
    // Overridden by narrow.css as they were in app.css; a panel's select width before the box line's, as before.
    for (const f of ["app/library.css", "app/lorebook.css", "app/trash.css"]) expect(at(f)).toBeGreaterThan(at("app.css")), expect(at(f)).toBeLessThan(at("app/narrow.css"));
    expect(at("app/fields.css")).toBeLessThan(at("app/narrow.css"));
    const fields = read("app/fields.css");
    expect(fields.indexOf(".side-panel .select-field")).toBeGreaterThan(-1);
    expect(fields.indexOf(".side-panel .select-field")).toBeLessThan(fields.indexOf(".item > .select-field"));
    expect(fields).toMatch(/\.item > \.select-field\s*\{[^}]*width:\s*140px/);
  });
});
