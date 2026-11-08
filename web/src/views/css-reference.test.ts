import { readFileSync } from "node:fs";
import { expect, test } from "vitest";
import { CLASSES, SNIPPETS, variables } from "./css-reference";

/** The stylesheet, read from its files with its parts in their places (vitest gives a test no CSS), from web/, where `npm test` runs. */
const read = (file: string): string => readFileSync(file, "utf8").replace(/@import "\.\/([^"]+)";/g, (_, part: string) => read(`src/${part}`));
const styles = read("src/styles.css");

/** The text of the stylesheet's blocks `:root`, the design system's and the app's, as the browser gives them: without their comments. */
const root = styles.replace(/\/\*[\s\S]*?\*\//g, "").match(/(?:^|\n):root ?\{[^}]*\}/g)!.join("\n");

test("every variable of the stylesheet's :root is listed with its light and its dark value, or its one value", () => {
  const listed = variables(root);
  expect(listed).toHaveLength(new Set(root.match(/--[\w-]+(?=\s*:)/g)).size);
  expect(listed).toContainEqual({ name: "--accent", light: "#0083E9", dark: "#3D95F5" });
  expect(listed).toContainEqual({ name: "--fs-body", light: "14px", dark: "14px" });
  // A light-dark() inside a longer value is told apart there too.
  expect(listed.find(({ name }) => name === "--shadow-tab")).toEqual({
    name: "--shadow-tab",
    light: "0 1px 3px rgba(0,0,0,.12),0 0 0 1px rgba(0,0,0,.06)",
    dark: "0 1px 3px transparent,0 0 0 1px rgba(255,255,255,.08)",
  });
});

test("every class name, and every name and variable of a snippet, is one the stylesheet has", () => {
  const named = (name: string) => new RegExp(String.raw`(^|[^\w-])${name.replaceAll(".", "\\.")}(?![\w-])`).test(styles);
  for (const { name } of CLASSES) expect(named(name), name).toBe(true);
  for (const { css } of SNIPPETS) {
    for (const name of css.replace(/\{[^}]*\}/g, "").match(/(?<![\w-])[.#][a-z][\w-]*/g) ?? []) expect(named(name), name).toBe(true);
    for (const variable of css.match(/--[\w-]+/g) ?? []) expect(root.includes(`${variable}:`), variable).toBe(true);
  }
});
